# GPUImage源码解读

> **导语：**很久之前就了解过GPUImage，但没有实际使用目标，处于游览状态，再加上当时对这方面的知识储备不足，看着看着就流产了。近期在不断的学习和使用的过程中，有了更深入的理解，特写一篇文章来介绍其功能及思路，以便后者能够快速上手。后期也会出实战篇，还请期待！

### 前言

GPUImage，是一个基于GPU进行图像处理的iOS开源框架，基于iOS技术的演变，其涉及三个版本系列，分别是基于`OC`语言和`OpenGL`技术的**GPUImage**、基于`Swift`语言和`OpenGL`技术的**GPUImage2**、基于`Swift`语言和`Metal`技术的**GPUImage3**。本文将基于第一版本的**GPUImage**进行解读，当然后续也会更新针对于后两个版本的解读。其思路基本一致，只是语言的语法（GPUImage与GPUImage2）或底层实现（GPUImage2与GPUImage3）有所区别。



### GPUImage的功能

GPUImage的主要功能就是对图像的处理，可分为三个步骤：图像资源的输入，对输入图像资源的处理，对处理完的图像资源输出。

#### 资源输入

- 摄像头采集图像数据：GPUImageVideoCamera

- 照片：GPUImgePicture

- 视频：GPUImageMovie

- OpenGL纹理：GPUImageTextureInput

- 二进制数据：GPUImageRawDataInput

- 视图：GPUImageUIElement



#### 资源处理

- 现成滤镜：GPUImage中内置了4大类125余种滤镜，包括颜色类、图像类、颜色混合、特效类等
- 滤镜链：GPUImageFilterPipeline可对滤镜链进行管理，单个pipeline实现串行，多个pipeline可实现并行。
- 自定义滤镜：支持自定义的滤镜拓展，只要继承自GPUImageFilter即可链接到滤镜处理上下文，无需再关注图像数据的来源和输出，只须专注于滤镜的核心算法即可。



#### 资源输出

- 实时预览：GPUImageView
- 视频文件：GPUImageMovieWriter
- GPU纹理：GPUImageTextureOutput
- 二进制数据：GPUImageRawDataOutput



### GPUImage涉及的技术知识

- 图像采集：AVCaptureSession 系列技术知识
- 视频文件读取：AVAssetReader 系列技术知识
- 视频文件保存：AVAssetWriter 系列技术知识
- OpenGL：OpenGL-ES 相关技术知识

当然，绝不仅仅是以上这点知识。



### GPUImage源码解读

这里解读的逻辑，就是按照前面介绍`GPUImage的功能`的顺序进行解读。

#### 资源输入

- **GPUImageOutput**

这是一个很基础，但又很重要的类，在解读`资源输入`的功能前必须得先介绍它。可能很多人有疑问，明明
