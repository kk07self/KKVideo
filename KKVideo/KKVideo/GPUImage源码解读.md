# GPUImage源码解读

> **导语：**很久之前就了解过GPUImage，但没有实际使用目标，处于游览状态，再加上当时对这方面的知识储备不足，看着看着就流产了。近期在不断的学习和使用的过程中，有了更深入的理解，特写一篇文章来介绍其功能及思路，以便有更多想了解GPUImage的伙伴能够快速上手。这一篇文章有别于已经出现的很多其他介绍GPUImage的文章，之前同仁出的多是介绍其有什么功能，如何使用，本篇文章将更多的介绍其功能实现的逻辑和思想，理解其功能实现的逻辑和思想后，如何使用那就是小儿科了，也更方便在其基础上拓展更多的特效滤镜，做更多的音视频处理功能。



## 前言

GPUImage，是一个基于GPU进行图像处理的iOS开源框架，基于iOS技术的演变，其涉及三个版本系列，分别是基于`OC`语言和`OpenGL`技术的**GPUImage**、基于`Swift`语言和`OpenGL`技术的**GPUImage2**、基于`Swift`语言和`Metal`技术的**GPUImage3**。本文将基于第一版本的**GPUImage**进行解读，当然后续也会更新针对于后两个版本的解读。其思路基本一致，只是语言的语法（GPUImage与GPUImage2）或底层实现（GPUImage2与GPUImage3）有所区别。



## GPUImage的功能

GPUImage的主要功能就是对图像的处理，可分为三个步骤：图像资源的输入，对输入图像资源的处理，对处理完的图像资源输出。

### 资源输入

- 摄像头采集图像数据：GPUImageVideoCamera

- 照片：GPUImgePicture

- 视频：GPUImageMovie

- OpenGL纹理：GPUImageTextureInput

- 二进制数据：GPUImageRawDataInput

- 视图：GPUImageUIElement

  

### 资源处理

- 现成滤镜：GPUImage中内置了4大类125余种滤镜，包括颜色类、图像类、颜色混合、特效类等
- 滤镜链：GPUImageFilterPipeline可对滤镜链进行管理，单个pipeline实现串行，多个pipeline可实现并行。
- 自定义滤镜：支持自定义的滤镜拓展，只要继承自GPUImageFilter即可链接到滤镜处理上下文，无需再关注图像数据的来源和输出，只须专注于滤镜的核心算法即可。



### 资源输出

- 实时预览：GPUImageView
- 视频文件：GPUImageMovieWriter
- GPU纹理：GPUImageTextureOutput
- 二进制数据：GPUImageRawDataOutput



## GPUImage涉及的技术知识

- 图像采集：AVCaptureSession 系列技术知识
- 视频文件读取：AVAssetReader 系列技术知识
- 视频文件保存：AVAssetWriter 系列技术知识
- OpenGL：OpenGL-ES 相关技术知识

当然，绝不仅仅是以上这点知识。



## GPUImage源码解读
纵览整个`GPUImage`的源码，凡涉及到上面提到的`GPUImage`的功能，都离不开一个类`GPUImageOutput`或一个协议`GPUImageInput`。
`输入资源`相关的功能都继承于`GPUImageOutput`这个类
`输出资源`相关的功能都遵守于`GPUImageInput`这个协议
`资源处理`相关的功能都继承于`GPUImageOutput`这个类，并遵守于`GPUImageInput`这个协议

因此，要深入的了解`GPUImage`这个库，解读里面的源码，就得先了解这一基类`GPUImageOutput`和这一协议`GPUImageInput`的功能，清楚了它两的功能原理后再来了解其他的功能，就是水到渠成的事了。


###  GPUImageOutput 
在解读`GPUImageOutput`源码前，先梳理下相关联的图像知识：
- **图像帧数据：**

  无论是视频还是图片，他们的基础单元都是一帧一帧的图像数据，至少照片是一帧图像数据，而视频是一串有时间先后顺序的图像帧数据。
  在图像处理中，我们看到的多数是`CVPixelBufferRef`或者`CMSampleBufferRef`指针代表的。

- **纹理Texture和framebuffer（FBO）：**
  熟悉`Opengl`的伙伴对这两个关键字会很熟悉，可以忽略直接跳过这点补充。
  图像帧数据可以通过`Opengl`绘制到纹理`Texture`上，`framebuffer`可以通过绑定纹理`Texture`，拿到经过纹理渲染后的数据导出图像帧数据。其实美颜、滤镜等特效就是通过纹理渲染（滤镜特效的特定算法）处理实现的。具体实现逻辑在后面`滤镜`模块会进行阐述，这里可以先忽略，只要知道一点就可以了：
  图像---> texture(framebuffer)---滤镜处理--->texture(framebuffer)---滤镜处理--->texture(framebuffer)······--->图像
  中间任何一部也都可以通过framebuffer导出图像。

  后面会使用`FBO`— 即帧缓存对象(framebuffer object) 来代表framebuffer解析阐述

  

接下来开始真正解读`GPUImageOutput`源码。

#### 图像资源的持有：`outputFramebuffer`
在`GPUImageOutput`的头文件里我们能看到`outputFramebuffer`这个属性，它是`GPUImageFramebuffer`类型的。
然后我们进一步到`GPUImageFramebuffer`这个类中，在头文件中我们能够看到一个熟悉的属性：`GLuint texture`，再到他的`.m`文件中，我们能看到另一个熟悉的属性：`GLuint framebuffer`。这个两个属性和我们刚刚提到的**纹理Texture和framebuffer**那个知识点联系了起来。

`GPUImageOutput`其实就是通过`outFramebuffer`将输入的图像关联起来，即渲染在纹理`texture`中，如果需要对图像进行滤镜处理，就可以获取`texture`进行再次纹理渲染，这也是为什么把`texture`放到头文件暴露处理的原因。如果在这过程中就需要使用图像，头文件中也暴露了对应的方法：

```objective-c
// 获取图像数据 二进制
- (GLubyte *)byteBuffer;
// 获取图像 pixelbuffer
- (CVPixelBufferRef)pixelBuffer;
// 获取图像 image
- (CGImageRef)newCGImageFromFramebufferContents;
```

而把`framebuffer`没有放到头文件暴露出去，也是因为如果想要图像我直接给三种格式的你随便取，而没必要拿到`framebuffer`自己再去实现一遍到图像的转换，另外framebuffer暴露出去后，也不容易管理，万一在某个处理过程中绑定纹理逻辑有误，会导致整个图像处理流程出错。



#### Targets

前面已经准备好图像资源了(outputFramebuffer)以及可以随时向下传递的纹理和FBO(texture,framebuffer)，接下来就是看如何传递到`图像处理对象`和`图像输出对象`了。

在`GPUImageOutput`头文件中我们能看到关于`target`的一系列的API：

```objective-c
- (NSArray*)targets;
- (void)addTarget:(id<GPUImageInput>)newTarget;
- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
- (void)removeTarget:(id<GPUImageInput>)targetToRemove;
- (void)removeAllTargets;
```

这一系列的API中的target就是功能中对应的`图像处理对象`或`图像输出对象`。我们发现每一个`target`需要都需要遵循`GPUImageInput`协议，这个协议下面会具体解读，这里先简单说下他的作用。遵循了`GPUImageInput`协议的对象就有了接收图像资源的传递及处理功能，当然这要实现协议中对应的方法(具体后面会阐述)。

这里可以简单举个示例：

`GPUImageVideoCamera`视频图像采集类，继承自`GPUImageOutput`，内部细节后续会描述。

`GPUImageView`图像显示类，遵循了`GPUImageInput`协议，内部细节后续会描述。

然后我们在控制器中实现如下代码：

```objective-c
// 属性声明
/** 相机 */
@property (nonatomic, strong) GPUImageVideoCamera *camera;
/** 预览视图 */
@property (nonatomic, strong) GPUImageView *filterView;

// viewdidload方法中：
// 创建camera
_camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
_camera.outputImageOrientation = UIInterfaceOrientationPortrait;
_camera.horizontallyMirrorFrontFacingCamera = YES;
// 创建预览视图
_filterView = [[GPUImageView alloc] initWithFrame:self.view.frame];
[self.view insertSubview:_filterView atIndex:0];
// 将预览视图(GPUImageInput)当作target添加到camera(GPUImageOutput)中
[_camera addTarget:_filterView];
// 启动相机
[_camera startCameraCapture];
```

以上简单一些代码，就实现了图像采集及预览的功能(图像资源输入(camera-采集)、图像资源输出(imageView-预览))。

`GPUImageOutput`类就先阐述这么多，其他的API看名字就能明了其功能，还有些需要解释的API个人觉得放在后面，结合对应的知识进行阐述会更加清楚明了。



### GPUImageInput

上一模块已经有提到这个协议的作用：遵循了`GPUImageInput`协议的对象就有了接收图像资源的传递及处理功能（需要实现协议中对应的方法）。

在这一节中，只会解读两个协议方法：

```objective-c
- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
```

#### 接收上一步的FBO(GPUImageFramebuffer)

这一功能，就是第一个协议方法`- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;`的作用。他是接收上一步(图像资源输入完成或者图像处理完成(滤镜))完成后，输出的FBO。在`GPUImageOutput`类中我们能看到这个方法：

```objective-c
- (void)setInputFramebufferForTarget:(id<GPUImageInput>)target atIndex:(NSInteger)inputTextureIndex;
{
    [target setInputFramebuffer:[self framebufferForOutput] atIndex:inputTextureIndex];
}
```

这是调用`target`的`- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex`这一方法，将我输出的`FBO`传递过去，当成`target`的输入的`FBO`。

因此，遵循这个协议的类，并实现这个方法，就能接收并保存传递过来的FBO，等到后面使用，也就是下一步要讲的。

#### 通知可以执行处理FBO了

`- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;`这一方法就是处理FBO的调用。在`GPUImageOutput`这个类中，没有看到用`target`调用这个方法，这是因为`GPUImageOutput`需要让其子类在准备好FBO后自己调用。比如`GPUImageVideoCamera`这个类，在`- (void)updateTargetsForVideoCameraUsingCacheTextureAtWidth:(int)bufferWidth height:(int)bufferHeight time:(CMTime)currentTime`这个方法中就有调用，而且是在其给`target`传递完`FBO`后，再进行调用的。

`GPUImageInput`的这两个重要协议的作用阐述完了，那么在具体实现怎么写，这个会在后面的功能中进行阐述。



### 资源输入

在`GPUImageOutput`章节，我们解读了`GPUImageOutput`及其子类如何持有图像数据`FBO(outputFramebuffer)`，并向下输出的，这一章节我们将解读资源输入对象的图像到底是如何转换成`FBO`的。

#### 摄像头采集图像数据：GPUImageVideoCamera

`GPUImageVideoCamera`是一个相机封装类，如果有想自己也自定义一个相机，建议参考这个类，封装的相对比较完善的。相机的如何封装，参数如何配置，其实不是本文的重点，但也会简单解读下。本文的重点是如何将采集的图像和前面提到的`FBO`进行转换，然后抛出。

- 相机封装

  - 相机初始化

  ```objective-c
  - (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;
  ```

  相机初始化的方法可设置两个参数，一个是设置采集图像的分辨率，一个是摄像头(可以设置前置还是后置摄像头)。

  分辨率可以查看`AVCaptureSessionPreset`里面支持的类型。

  - 相机摄像头切换

  ```objective-c
  // 切换摄像头
  - (void)rotateCamera;
  // 获取当前摄像头
  - (AVCaptureDevicePosition)cameraPosition;
  ```

  初始化的时候有设置`摄像头`，那么在开始后一定有切换`摄像头`的需求，这里也提供了API，方便用户切换`摄像头`。

  - 切换分辨率

  ```objective-c
  @property (readwrite, nonatomic, copy) NSString *captureSessionPreset;
  ```

  同样，初始化的时候设置了`分辨率`，后面如果想要调整，这里也提供了API。

  - 相机暂停继续等状态控制

  ```objective-c
  /** Start camera capturing */
  - (void)startCameraCapture;
  /** Stop camera capturing */
  - (void)stopCameraCapture;
  /** Pause camera capturing */
  - (void)pauseCameraCapture;
  /** Resume camera capturing*/
  - (void)resumeCameraCapture;
  ```

  这里对相机采集的视频流也做了控制，开始、暂停、继续、停止等。其实进入实现里面，我们能发现，暂停只是做了标记，而数据采集依然在执行，只是这个标记会控制采集的数据不被抛出和处理。

  - 图像采集输出格式配置

  这一部分没有暴露出来，在内部初始化的时候进行了配置，支持RGBA格式、YUV（420f，420p）格式

  ```objective-c
  if (supportsFullYUVRange)
  {
      [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
      isFullYUVRange = YES;
  }
  else
  {
      [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
      isFullYUVRange = NO;
  }
  
  // 另外的判断
  {
      [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
  }
  ```

  - 帧率设置

  ```objective-c
  @property (readwrite) int32_t frameRate;
  ```

  帧率设置的API

  

  - 图像帧数据回调

  ```objective-c
  - (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;
  ```

  …...

  

- 图像帧数据转FBO

  - 找到最原始的帧数据

  相机采集到数据后，有个代理回调，里面抛出了相机采集的帧数据。在`GPUImageVideoCamera`中我们找到了这个回调:

  ```objective-c
  - (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
  ```

  在这里，拿到了最原始的图像帧数据了。

  - 原始帧数据处理

  继续在上面的回调方法中探索，我们发现`GPUImageVideoCamera`将帧数据扔到了这个方法

  ```objective-c
  - (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
  ```

  里面进行了处理。在这个方法里，我们可以看到这个过程：

  过程1：(CMSampleBufferRef)sampleBuffer -------> (CVImageBufferRef)cameraFrame;

  过程2：(CVImageBufferRef)cameraFrame ---opengl---> outputFramebuffer(texture/framebuffer);

  过程2中分了两个分支，一个是帧数据是YUV格式的处理方式，一个是RGBA格式的处理方法。(`工具收集:既然研究了GPUImage,后期一定会处理视频格式的转换，尤其是YUV与RGBA格式间的转换，这里转换的工具就可以收集起来，后期一定会用到，nice`)。这里的转换用的是`opengl`的知识，如果之前有了解甚好，如果不了解也没关系，不妨碍解读整个`GPUImage`的工作原理。

  - 帧数据的传递(抛出)

  前两步已经实现了将帧数据绑定给了`FBO`，资源输入的这一步其实也就完成了。为了与前面介绍`GPUImageOutput`和`GPUImageInput`中帧数据传递的功能相呼应，这里就再深入一步解读。

  在方法：

  ```objective-c
  - (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
  ```

  中处理完上面的转换后，我们能看到调用了这样一个方法：

  ```objective-c
  [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:rotatedImageBufferWidth height:rotatedImageBufferHeight time:currentTime];
  ```

  我们跟进去，发现和我们之前介绍`GPUImageOutput`和`GPUImageInput`时，FBO传递的逻辑关联在了一起：

  在方法：

  ```objective-c
  - (void)updateTargetsForVideoCameraUsingCacheTextureAtWidth:(int)bufferWidth height:(int)bufferHeight time:(CMTime)currentTime;
  ```

  中，先是遍历了`targets`，然后给每一个`target(GPUImageInput)`传递去了`FBO`

  ```objective-c
  [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
  ```

  然后是再遍历`targets`，让每一个`target`调用处理图像数据(这时候已经是FBO)了的方法：

  ```objective-c
  [currentTarget newFrameReadyAtTime:currentTime atIndex:textureIndexOfTarget];
  ```

  现在我们再回过头看之前的小示例代码：

  ```objective-c
  // 属性声明
  /** 相机 */
  @property (nonatomic, strong) GPUImageVideoCamera *camera;
  /** 预览视图 */
  @property (nonatomic, strong) GPUImageView *filterView;
  
  // viewdidload方法中：
  // 创建camera
  _camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
  _camera.outputImageOrientation = UIInterfaceOrientationPortrait;
  _camera.horizontallyMirrorFrontFacingCamera = YES;
  // 创建预览视图
  _filterView = [[GPUImageView alloc] initWithFrame:self.view.frame];
  [self.view insertSubview:_filterView atIndex:0];
  // 将预览视图(GPUImageInput)当作target添加到camera(GPUImageOutput)中
  [_camera addTarget:_filterView];
  // 启动相机
  [_camera startCameraCapture];
  ```

  这时候就明白了，为什么把`_filterView`添加到`_camera`上就能得到采集的图像数据进行显示了(拿到FBO如何显示在视图View上，这个后面会解读)。

目前为止，`GPUImageVideoCamera`在`GPUImage`中作为`资源输入`的角色扮演完了：获取到图像原始数据，绑定给FBO，传递给资源处理器或资源输出(遵守了GPUImageInput协议的target)。

其他的`资源输入`类型的原理和这基本一致，这里我们再挑几个简单的先解读。



#### 照片：GPUImgePicture

- 图像资源来源

先来看一组`GPUImagePicture`的初始化API：

```objective-c
// Initialization and teardown
- (id)initWithURL:(NSURL *)url;
- (id)initWithImage:(UIImage *)newImageSource;
- (id)initWithCGImage:(CGImageRef)newImageSource;
- (id)initWithImage:(UIImage *)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput;
- (id)initWithCGImage:(CGImageRef)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput;
- (id)initWithImage:(UIImage *)newImageSource removePremultiplication:(BOOL)removePremultiplication;
- (id)initWithCGImage:(CGImageRef)newImageSource removePremultiplication:(BOOL)removePremultiplication;
- (id)initWithImage:(UIImage *)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput removePremultiplication:(BOOL)removePremultiplication;
- (id)initWithCGImage:(CGImageRef)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput removePremultiplication:(BOOL)removePremultiplication;
```

这系列的初始化的API中都有一个关于图像资源的参数`url`或`newImageSource`。`GPUImgePicture`的图像资源就来源于此。相比较于`GPUImageVideoCamera`处理一系列帧数据来说，`GPUImagePicture`只处理一帧的图像资源。

- 图像资源转FBO

上一步我们拿到了图像资源，继续跟进去，所有的初始化方法都会进入到终极初始化方法里：

```objective-c
- (id)initWithCGImage:(CGImageRef)newImageSource smoothlyScaleOutput:(BOOL)smoothlyScaleOutput removePremultiplication:(BOOL)removePremultiplication;
```

在这里我们看到这两步：

newImageSource—————>imageData;

imageData—————>outputFramebuffer

同`GPUImageVideoCamera`一样，最终会到`outputFramebuffer`这里，只是输入的图像资源格式不一样，处理过程不一样而已。

- 图像资源传递/处理

和`GPUImageVideoCamera`不一样，`GPUImageVideoCamera`会源源不断的抛出很多图像资源进行处理，所以他的传递都是自动的，获取到图像资源就传递抛出去接下一个。`GPUImagePicture`是需要外部调用对应的API：

```objective-c
- (void)processImage;
- (BOOL)processImageWithCompletionHandler:(void (^)(void))completion;
- (void)processImageUpToFilter:(GPUImageOutput<GPUImageInput> *)finalFilterInChain withCompletionHandler:(void (^)(UIImage *processedImage))block;
```

这里给了三个API，其中两个有回调的，再其中一个是指定到具体的`filter`后获取其处理过的图片。

继续追踪其内部的执行逻辑，发现和`GPUImageVideoCamera`基本一致，遍历`targets`给每一个`target`传递`FBO`，然后告知处理`FBO`:

```objective-c
for (id<GPUImageInput> currentTarget in targets)
{
  NSInteger indexOfObject = [targets indexOfObject:currentTarget];
  NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
  [currentTarget setCurrentlyReceivingMonochromeInput:NO];
  [currentTarget setInputSize:pixelSizeOfImage atIndex:textureIndexOfTarget];
  [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
  [currentTarget newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureIndexOfTarget];
}
```

- GPUImagePicture+TextureSubimage

这是对`GPUImagePicture`的拓展

```objective-c
- (void)replaceTextureWithSubimage:(UIImage*)subimage;
- (void)replaceTextureWithSubCGImage:(CGImageRef)subimageSource;
- (void)replaceTextureWithSubimage:(UIImage*)subimage inRect:(CGRect)subRect;
- (void)replaceTextureWithSubCGImage:(CGImageRef)subimageSource inRect:(CGRect)subRect;
```

为了满足这样的需求：添加了`targets(处理或输出)`后，只替换图像原始数据，而不需要重新再添加这些`targets`。



#### 视频：GPUImageMovie



#### OpenGL纹理：GPUImageTextureInput、二进制数据：GPUImageRawDataInput、视图：GPUImageUIElement

有了上面的铺垫，这里的三个`资源输入`相对就很简单，这里就一笔带过。

- GPUImageTextureInput

直接输入的资源是纹理`texture`，这个直接绑定给`FBO`即可完成到`FBO`的桥接。

- GPUImageRawDataInput

这个的输入资源是二进制的图片数据，对比`GPUImagePicture`，少了图像转二进制图像数据的步骤，直接将数据绘制到纹理`texture`中然后绑定在`FBO`上

- GPUImageUIElement

这个传入的是视图控件，相对于`GPUImageRawDataInput`多了一步将自己的`layer`转换成二进制图文数据，后面的步骤就和`GPUImageRawDataInput`一样了。

#### 



#### 


### 滤镜
#### 滤镜工作原理
#### 滤镜基类
#### 内置滤镜
#### 滤镜链
#### 自定义滤镜


### 资源输出
#### 实时预览：GPUImageView
#### 视频文件：GPUImageMovieWriter
#### GPU纹理：GPUImageTextureOutput
#### 二进制数据：GPUImageRawDataOutput


### 其他
#### 线程

#### OpenGL


#### GPUImageFramebufferCache
