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

`GPUImageMovie`是一个视频读取类，初始化时传入视频资源，即可抛出类似`GPUImageVideoCamera`一样一系列的图像帧，其内部出了图像资源的获取外，其他的逻辑（图像->FBO，FBO->传递target）和`GPUImageVideoCamera`几乎完全一样。

- 获取图像资源

  - 初始化传递视频资源

  ```objective-c
  - (id)initWithAsset:(AVAsset *)asset;
  - (id)initWithPlayerItem:(AVPlayerItem *)playerItem;
  - (id)initWithURL:(NSURL *)url;
  ```

  三个初始化方法，分别接受不一样的视频资源，然后将其保存到`GPUImageMovie`对象中，留有后面使用。

  - 视频资源读取->图像资源

  针对上一步`GPUImageMovie`初始化时传进来的视频资源，`GPUImageMovie`其解析出来的图像资源的过程也是不一样的。

  **AVPlayerItem**作为资源时：

  `GPUImageMovie`通过`AVPlayerItemOut`来进行解析：

  首先，在`- (void)processPlayerItem`方法中，配置`AVPlayerItemOutput`并添加定时器`displayLink`具体请看`- (void)processPlayerItem`这个方法；

  然后，在`displayLink`定时器的回调中配置要读取的图像帧的时间，在`- (void)displayLinkCallback:(CADisplayLink *)sender`回调方法中实现；

  最后，通过定时器配置的时间，从`AVPlayerItemOutput`中读取对应时间的图像帧，具体实现在`- (void)processPixelBufferAtTime:(CMTime)outputItemTime`方法中，最终拿到图像帧资源：

  ```objective-c
  CVPixelBufferRef pixelBuffer = [playerItemOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
  ```

  

  **AVAsset或NSURL**作为资源是：

  `GPUIMageMovie`通过`AVAssetReader`来进行解析：

  首先，在`- (void)processAsset`方法中，创建`AVAssetReader`对象，并配置其参数信息

  然后，再在创建`AVAssetReader`后，通过`while`循环用`AVAssetReader`读取图像帧数据，可参看`- (void)processAsset`中的`while`循环体，及其在循环体中调用的这个方法的实现

  `- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput`

  

  以上，拿到了图像帧数据，下面就是转FBO了。

  

- 图像资源转FBO

上一步拿到的每一帧的图像资源，都会进入到这个方法：

```objective-c
- (void)processMovieFrame:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime;
```

这个方法中会通过Opengl将图像帧数据转成`FBO`，这一套的逻辑和`GPUImageVideoCamera`中的一模一样。

- 图像资源传递/处理

同`GPUImageVideoCamera`一样，在将图像转成`FBO`后，将`FBO`传递给自己的`targets`：

```objective-c
for (id<GPUImageInput> currentTarget in targets)
{
    NSInteger indexOfObject = [targets indexOfObject:currentTarget];
    NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
    [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:targetTextureIndex];
    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
}

[outputFramebuffer unlock];

for (id<GPUImageInput> currentTarget in targets)
{
    NSInteger indexOfObject = [targets indexOfObject:currentTarget];
    NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
    [currentTarget newFrameReadyAtTime:currentSampleTime atIndex:targetTextureIndex];
}
```



以上，基本上就将`GPUImageMovie`解读完了。其实，在`GPUImageMovie`中，很好的封装了从视频中读出一帧一帧的图像资源，如果后期有这方面的需求，建议可以参考此类，可以方便很多。



#### OpenGL纹理：GPUImageTextureInput、二进制数据：GPUImageRawDataInput、视图：GPUImageUIElement

有了上面的铺垫，这里的三个`资源输入`相对就很简单，这里就一笔带过。

- GPUImageTextureInput

直接输入的资源是纹理`texture`，这个直接绑定给`FBO`即可完成到`FBO`的桥接。

- GPUImageRawDataInput

这个的输入资源是二进制的图片数据，对比`GPUImagePicture`，少了图像转二进制图像数据的步骤，直接将数据绘制到纹理`texture`中然后绑定在`FBO`上

- GPUImageUIElement

这个传入的是视图控件，相对于`GPUImageRawDataInput`多了一步将自己的`layer`转换成二进制图文数据，后面的步骤就和`GPUImageRawDataInput`一样了。

#### 


### 滤镜
#### 滤镜工作原理

- 滤镜处理的流程

图像———》纹理（texture）、FBO（绑定了texture的帧缓存对象）———》着色器渲染———》新的纹理(texture）、FBO———>图像

第一步的图像转纹理和最后一步的纹理转图像，前面已经进行过阐述，那么这里会重点阐述纹理渲染的过程。

- 纹理渲染

纹理渲染，实际上是通过`着色器`对纹理进行渲染。这里会涉及到两个`着色器`，分别是`顶点着色器-Vertex Shader`和`片段着色器-Fragment Shader`。

**顶点着色器**

```objective-c
NSString *const kGPUImageVertexShaderString = SHADER_STRING
(
 attribute vec4 position; // 接收顶点坐标
 attribute vec4 inputTextureCoordinate; // 接收纹理坐标
 
 varying vec2 textureCoordinate; // 向外传递纹理坐标
 
 void main()
 {
     gl_Position = position; // 顶点坐标给到gl
     textureCoordinate = inputTextureCoordinate.xy; // 纹理坐标复制
 }
 );
```

`顶点着色器`主要工作是接收`顶点坐标`和`纹理坐标`，告知系统是从哪个位置开始绘制，绘制多大；并将`纹理坐标`传递给`片段着色器`

**片段着色器**

```objective-c
NSString *const kGPUImagePassthroughFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate; // 接收的纹理坐标
 
 uniform sampler2D inputImageTexture; // 接收的图像纹理
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate); // 纹理绘制
 }
);
```

`片段着色器`主要工作是拿到`纹理坐标`和`纹理`告诉系统如何绘制，上面的示例是最简单的，没有进行任何算法的处理。

**使用着色器**

这一系列的知识涉及到的`opengl`的很多知识，这里就不铺开阐述了，如果感兴趣可以查看我的另一系列的文章[LearnOpengl](https://github.com/kk07self/LearnOpenGL)，当然在后面介绍一些滤镜的时候会顺带介绍。

#### 滤镜基类

`GPUImageFilter`，这是滤镜的基类，说是滤镜的基类，一是它包含了滤镜处理的基础配置(如上文提到的`顶点着色器`、'片段着色器'以及`着色器的使用`等)；二是它虽然是一个滤镜，但是是无效果的滤镜，没有对图像进行任何处理，怎么输入就怎么输出的。下面来具体解析下：

- 接收、处理、传递图像

`GPUImageFilter`首先是遵循了`GPUImageInput`协议，前文有解析过，遵循了这个协议的类，实现对应的方法，就有了接收和处理图像的功能。然后是继承自`GPUImageOutput`，同样前文也有解析过，继承自它的类，就有了向下(外)传递图像的功能(添加到targets)里。

```objective-c
- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    firstInputFramebuffer = newInputFramebuffer;
    [firstInputFramebuffer lock];
}
```

在`GPUImageFilter`的实现文件里面，我们看到了上面这个方法的实现，即接收了图像的`FBO`。

```objective-c
- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
```

接着在`GPUImageFilter`中，也实现了这个方法，这是上一步告诉下一步可以处理图像了的调用。继续看这个方法里面的实现，我们看到调用了这个方法：

```objective-c
[self renderToTextureWithVertices:imageVertices textureCoordinates:[[self class] textureCoordinatesForRotation:inputRotation]];
```

我们进入这个方法的实现中，可以看到这里面就是通过`opengl`对图像进行的`滤镜`处理。里面如何渲染的，等到后面梳理了着色器配置后再进行解析。

- 滤镜处理过程

**着色器配置及解析**

滤镜的初始化方法中有参数是让配置着色器的：

```objective-c
- (id)initWithVertexShaderFromString:(NSString *)vertexShaderString fragmentShaderFromString:(NSString *)fragmentShaderString;
```

这个API中，`vertexShaderString`是配置`顶点着色器`，`fragmentShaderString`配置`片段着色器`。这两个参数决定了，滤镜内部是如何绘制的。

在进入到它的实现里，我们可以看到这样一段代码：

```objective-c
runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];

        // 创建滤镜程序
        filterProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
        
        if (!filterProgram.initialized)
        {
            [self initializeAttributes];
            
            if (![filterProgram link])
            {
                NSString *progLog = [filterProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [filterProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [filterProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                filterProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
  			// 着色器中读取出 顶点坐标、纹理坐标、纹理等参数
        filterPositionAttribute = [filterProgram attributeIndex:@"position"];
        filterTextureCoordinateAttribute = [filterProgram attributeIndex:@"inputTextureCoordinate"];
        filterInputTextureUniform = [filterProgram uniformIndex:@"inputImageTexture"]; // This does assume a name of "inputImageTexture" for the fragment shader
        
        [GPUImageContext setActiveShaderProgram:filterProgram];
        
  			// enable 顶点坐标
        glEnableVertexAttribArray(filterPositionAttribute);
        glEnableVertexAttribArray(filterTextureCoordinateAttribute);    
    });
```

这段代码的作用大致是：

1 通过`顶点着色器`和`片段着色器`创建`着色器程序`

2 读取出`着色器`中需要传入的值参数，即`顶点坐标`、`纹理坐标`及`纹理`

**纹理渲染**

在`GPUImageFilter`这一节的前面，已经阐述了在初始化的时候通过`着色器`创建的`着色器程序`，以及`着色器`中接收`顶点坐标`、`纹理坐标`、及`纹理`的参数入口；并且接收了上一层传递下来的图像资源`FBO`，保存在了`FirstInputFrameBuffer`中；最后来到了渲染纹理的方法中了。接下来就具体解析下，纹理渲染的方法。

```objective-c
- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    // 激活着色器程序
    [GPUImageContext setActiveShaderProgram:filterProgram];

  	// 绑定激活outputFramebuffer, FBO 
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
  	// 方法里面是
  	// glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    // glViewport(0, 0, (int)_size.width, (int)_size.height);
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }

    [self setUniformsForProgramAtIndex:0];
    
  // 清空纹理屏上的信息
  glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
  glClear(GL_COLOR_BUFFER_BIT);

  // 激活纹理，绑定输入的纹理
	glActiveTexture(GL_TEXTURE2);
	glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
	
  // 将纹理传递给 片段着色器
	glUniform1i(filterInputTextureUniform, 2);	

  // 将顶点坐标和纹理坐标传递给顶点着色器
  glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
	glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
  
  // 开始纹理渲染
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
}
```

上面代码的注释，其实就是前文提到的`顶点着色器`、`片段着色器`如何作用到纹理到达滤镜的效果。这里再简单总结下：

1 着色器(顶点、片段)创建着色器程序，读出着色器中接收信息（顶点坐标、纹理坐标、纹理）的参数

2 激活着色器程序，即使用程序

3 绑定FBO到 ，即

4 激活纹理，传递纹理值

5 传递顶点坐标及其他参数

6 开始绘制

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
