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
/** Returns an array of the current targets.
 */
- (NSArray*)targets;

/** Adds a target to receive notifications when new frames are available.
 The target will be asked for its next available texture.
 See [GPUImageInput newFrameReadyAtTime:]
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget;

/** Adds a target to receive notifications when new frames are available.
 See [GPUImageInput newFrameReadyAtTime:]
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;

/** Removes a target. The target will no longer receive notifications when new frames are available.
 @param targetToRemove Target to be removed
 */
- (void)removeTarget:(id<GPUImageInput>)targetToRemove;

/** Removes all targets.
 */
- (void)removeAllTargets;
```

这一系列的API中的target就是功能中对应的`图像处理对象`或`图像输出对象`。我们发现每一个`target`需要都需要遵循`GPUImageInput`协议，这个协议下面会具体解读，这里先简单说下他的作用。遵循了`GPUImageInput`协议的对象就有了接收图像资源的传递及处理功能，当然这要实现协议中对应的方法(具体后面会阐述)。

这里可以简单举个示例：

`GPUImageVideoCamera`视频图像采集类，继承自`GPUImageOutput`，内部细节后续会描述。

`GPUImageView`图像显示类，遵循了`GPUImageInput`协议，内部细节后续会描述。

然后我们在控制器中实现如下代码：

```objective-c
// 属性声明
/**
 相机
 */
@property (nonatomic, strong) GPUImageVideoCamera *camera;

/**
 预览视图
 */
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
#### 摄像头采集图像数据：GPUImageVideoCamera

#### 照片：GPUImgePicture

#### 视频：GPUImageMovie

#### OpenGL纹理：GPUImageTextureInput

#### 二进制数据：GPUImageRawDataInput

#### 视图：GPUImageUIElement


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
