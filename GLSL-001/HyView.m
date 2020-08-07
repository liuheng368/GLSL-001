//
//  HyView.m
//  GLSL-001
//
//  Created by Henry on 2020/8/6.
//  Copyright © 2020 刘恒. All rights reserved.
//

#import "HyView.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface HyView()

@property(nonatomic,strong)CAEAGLLayer *myLayer;
@property(nonatomic,strong)EAGLContext *myContent;

@property(nonatomic,assign)GLuint myRenderBuffer;
@property(nonatomic,assign)GLuint myFrameBuffer;

@property(nonatomic,assign)GLuint myProgram;
@end

@implementation HyView
/*
 绘制:
    1. EAGLLayer获取,设置layer图层
    2. content创建
    3. 清空缓存区（frameBuffer，renderBuffer）
    4. 设置renderBuffer
    5. 设置frameBuffer
    6. 开始绘制
 手动编译、链接着色器程序：
    1. 顶点、片元着色器ID创建
    2. 着色器文件读取
    3. 着色器文件附着到着色器上
    4. 着色器编译
    5. 程序ID创建
    6. 着色器附着到程序上
    7. 清理着色器内存
    8. 程序链接 - 8.1链接状态获取
    9.使用program

 */
- (void)layoutSubviews{
    //1. EAGLLayer获取,设置layer图层
    [self setupLayout];
    //2. content创建
    [self setupContent];
    //3.清空缓存区
    [self cleanBuffer];
    //4. 设置renderBuffer
    [self setRenderBuffer];
    //5. 设置frameBuffer
    [self setFrameBuffer];
    //6. 绘制对应纹理
    [self setupTexture];
}


//MARK: 1. EAGLLayer获取,设置layer图层
+ (Class)layerClass{
    //1.需要重写view的子类方法，返回特定的layer，否则所有绘制动作是无效的
    return [CAEAGLLayer class];
}
-(void)setupLayout {
    //2.获取layer
    //view中存在一个特殊的图层，用于OpenGL的渲染
    self.myLayer = (CAEAGLLayer *)self.layer;
    
    //3.设置scale
    CGFloat scale = [[UIScreen mainScreen] scale];
    [self setContentScaleFactor:scale];
    
    //4.设置描述属性
    /*
      kEAGLDrawablePropertyRetainedBacking  表示绘图表面显示后，是否保留其内容。
      kEAGLDrawablePropertyColorFormat 可绘制表面的内部颜色缓存区格式。这个key对应的值是一个NSString指定特定颜色缓存区对象。默认是kEAGLColorFormatRGBA8；
     */
    self.myLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking:@false,
                                        kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8};
}

//MARK: 2. content创建
-(void)setupContent{
    //1. 创建上下文
    self.myContent = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if(!self.myContent){
        NSLog(@"create content failed");
        return;
    }
    
    //2.设置图形上下文
    if(![EAGLContext setCurrentContext:self.myContent]){
        NSLog(@"set Current Context failed");
        return;
    }
}

//MARK: 3.清空缓存区
-(void)cleanBuffer {
    /*
    buffer分为frame buffer 和 render buffer2个大类。
    其中frame buffer 相当于render buffer的管理者。
    frame buffer object即称FBO。
    render buffer则又可分为3类。colorBuffer、depthBuffer、stencilBuffer。
    */
    
    //1. 清空渲染缓存区
    //该渲染缓存区被重置为0，被标记为未使用。与之连接的帧缓存区也被断开。
    glDeleteRenderbuffers(1, &_myRenderBuffer);
    
    //2. 清空帧缓存区
    //使用该函数和glDeleteFramebuffers效果相同，但是renderBuffer也可以使用
    glDeleteBuffers(1, &_myFrameBuffer);
}

//MARK: 4. 设置renderBuffer
-(void)setRenderBuffer{
    //1. 创建渲染缓冲区ID
    GLuint rBuffer;
    glGenRenderbuffers(1, &rBuffer);
    
    //2. 绑定缓冲区
    glBindRenderbuffer(GL_RENDERBUFFER, rBuffer);
    
    //3. 将可绘制对象drawable object's  CAEAGLLayer的存储绑定到OpenGL ES renderBuffer对象
    [self.myContent renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.myLayer];
    
    self.myRenderBuffer = rBuffer;
}

//MARL: 5. 设置frameBuffer(FBO)
-(void)setFrameBuffer{
    //1. 创建渲染缓冲区ID
    GLuint fBuffer;
    glGenFramebuffers(1, &fBuffer);
    
    //2. 绑定缓冲区
    glBindFramebuffer(GL_FRAMEBUFFER, fBuffer);
    
    
    /*3. 生成帧缓存区之后，则需要将renderbuffer跟framebuffer进行绑定，
     使用函数进将渲染缓存区绑定到d帧缓存区对应的颜色附着点上，后面的绘制才能起作用
    */
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.myRenderBuffer);
}

//MARK: 6. 绘制对应纹理
-(void)setupTexture{
    //1. 设置清屏颜色，颜色缓存区
    glClearColor(0.3, 0.2, 0.7, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    //2.设置视口
    CGFloat scale = [[UIScreen mainScreen] scale];
    glViewport(self.frame.origin.x * scale,
               self.frame.origin.y * scale,
               self.frame.size.width * scale,
               self.frame.size.height * scale);
    
    //3. 读取着色器地址
    NSString *verFile = [[NSBundle mainBundle] pathForResource:@"shaderv" ofType:@"vsh"];
    NSString *framFile = [[NSBundle mainBundle] pathForResource:@"shaderf" ofType:@"fsh"];
    
    //4. 加载、编译着色器，编辑、链接程序对象
    self.myProgram = [self startShaderProgram:verFile fFile:framFile];
    
    //5.设置顶点、纹理坐标
    //前3个是顶点坐标，后2个是纹理坐标
    GLfloat attrArr[] =
    {
        0.5f, -0.5f, -1.0f,     1.0f, 0.0f,
        -0.5f, 0.5f, -1.0f,     0.0f, 1.0f,
        -0.5f, -0.5f, -1.0f,    0.0f, 0.0f,
        
        0.5f, 0.5f, -1.0f,      1.0f, 1.0f,
        -0.5f, 0.5f, -1.0f,     0.0f, 1.0f,
        0.5f, -0.5f, -1.0f,     1.0f, 0.0f,
    };
    
    //6.-----创建顶点缓存区--------
    //6.1 创建顶点缓存区
    GLuint vertex;
    glGenBuffers(1, &vertex);
    //6.2 绑定顶点缓存区
    glBindBuffer(GL_ARRAY_BUFFER, vertex);
    //6.3 将数据从内存中读取到顶点缓存区中
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), attrArr, GL_STATIC_DRAW);
    
    //7.-----处理顶点数据--------
    //7.1 获取顶点着色器中限定符为：attribute的句柄
    //注意：第二参数字符串必须和顶点着色器中的输入变量名保持一致
    GLuint position = glGetAttribLocation(self.myProgram, "position");
    //7.2 允许该变量position读取顶点缓存区的数据
    glEnableVertexAttribArray(position);
    //7.3 设置positions通过何种方式从顶点缓存区中读取顶点数据
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (float *)NULL + 0);
    
    //8.-----处理纹理坐标数据--------
    //8.1 获取顶点着色器中限定符为：attribute的句柄
    GLuint texCoord = glGetAttribLocation(self.myProgram, "textureCoord");
    //8.2 允许该变量texCoord读取顶点缓存区的数据
    glEnableVertexAttribArray(texCoord);
    //8.3 设置texCoord通过何种方式从顶点缓存区中读取纹理数据
    glVertexAttribPointer(texCoord, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (float *)NULL + 3);
    
    //9. 加载纹理图片
    [self loadImage:@"cat"];
    
    //10.-----处理纹理数据--------
    //10.1 获取着色器中限定符为：uniform的句柄
    GLuint texture = glGetUniformLocation(self.myProgram, "textureMap");
    //10.2 设置texture读取帧缓存区中的对应纹理ID=0（参数2）的纹理
    glUniform1f(texture, 0);
    
    //11. 绘制
    glDrawArrays(GL_TRIANGLES, 0, 6);
    
    //12. 从渲染缓存区显示到屏幕上
    [self.myContent presentRenderbuffer:GL_RENDERBUFFER];
    
    //glVertexAttribPointer参数解释可参考[OpenGLES（二）- 纹理贴图](https://www.jianshu.com/p/91a3c4d27e16)
}
//加载纹理图片
-(BOOL)loadImage:(NSString *)picName{
    //1.将UIImage转为CGImage
    CGImageRef ref = [UIImage imageNamed:picName].CGImage;
    //判断图片是否获取成功
    if (!ref) {
        NSLog(@"Failed to load image %@", picName);
        return NO;
    }
    
    //2.读取图片大小、颜色空间
    size_t width = CGImageGetWidth(ref);
    size_t height = CGImageGetHeight(ref);
    CGColorSpaceRef space = CGImageGetColorSpace(ref);
    
    //3. 初始化接收图片数据的变量
    GLubyte * spriteData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
    
    //4.创建coreGraphics的上下文
    /*
    参数1：data,指向要渲染的绘制图像的内存地址
    参数2：width,bitmap的宽度，单位为像素
    参数3：height,bitmap的高度，单位为像素
    参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
    参数5：bytesPerRow,bitmap的每一行的内存所占的比特数
    参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
    */
    CGContextRef contentRef = CGBitmapContextCreate(spriteData, width, height, 8, width*4, space, kCGImageAlphaPremultipliedLast);
    
    //5. 将CGImage在CGContextRef上绘制出来
    /*
    CGContextDrawImage 使用的是Core Graphics框架，坐标系与UIKit 不一样。UIKit框架的原点在屏幕的左上角，Core Graphics框架的原点在屏幕的左下角。
    CGContextDrawImage
    参数1：绘图上下文
    参数2：rect坐标
    参数3：绘制的图片
    */
    CGContextDrawImage(contentRef, CGRectMake(0, 0, width, height), ref);
    
    //6. 绘制完毕后释放CG上下文
    CGContextRelease(contentRef);
    //以上步骤统称为图片解压缩
    
    //7. 激活纹理空间
    //OpenGL中纹理ID0默认打开，所以该方法可省略
    //glActiveTexture(0);
    
    //8. 绑定纹理ID
    glBindTexture(GL_TEXTURE_2D, 0);
    
    //9. 设置纹理ID的参数
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    //10. 载入纹理到帧缓存区中，并对应纹理ID=0
    float fw = width, fh = height;
    /*
    参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
    参数2：加载的层次，一般设置为0
    参数3：纹理的颜色值GL_RGBA
    参数4：宽
    参数5：高
    参数6：border，边界宽度
    参数7：format
    参数8：type
    参数9：纹理数据
    */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fw, fh, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);
    return YES;
}


//MARK: 着色器程序
/// 着色器程序启动
/// @param vertex <#vertex description#>
/// @param fragment <#fragment description#>
-(GLuint)startShaderProgram:(NSString *)vertex fFile:(NSString *)fragment{
    //定义2个零时着色器对象
    GLuint verSharder, fragSharder;
    //着色器编译
    [self compileShader:&verSharder type:GL_VERTEX_SHADER path:vertex];
    [self compileShader:&fragSharder type:GL_FRAGMENT_SHADER path:fragment];
    //程序编译
    GLuint program;
    program = [self compileProgram:verSharder frag:fragSharder];
    //程序链接
    [self linkProgram:program];
    return program;
}


/// 顶点着色器创建、编译
/// @param shader <#shader description#>
/// @param type <#type description#>
/// @param path <#path description#>
-(void)compileShader:(GLuint *)shader type:(GLenum)type path:(NSString *)path{
    //1. 顶点、片元着色器ID创建
    *shader = glCreateShader(type);
    
    //2. 读取着色器文件
    NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    //转为c字符串
     const GLchar* cSource = [source UTF8String];
    
    //3.将着色器源码附加到着色器对象上。
    //参数1：shader,要编译的着色器对象 *shader
    //参数2：numOfStrings,传递的源码字符串数量 1个
    //参数3：strings,着色器程序的源码（真正的着色器程序源码）
    //参数4：lenOfStrings,长度，具有每个字符串长度的数组，或NULL，这意味着字符串是NULL终止的
    glShaderSource(*shader, 1, &cSource, NULL);
    
    //4.着色器编译
    glCompileShader(*shader);
}

/// 程序对象创建
/// @param vertexShader <#vertexShader description#>
/// @param fragShader <#fragShader description#>
-(GLuint)compileProgram:(GLuint)vertexShader frag:(GLuint)fragShader {
    //5. 程序ID创建
    GLint program = glCreateProgram();
    
    //6. 着色器附着到程序上,创建最终的程序
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragShader);
    
    //7. 不会立即删除着色器，而是将着色器进行标记，等待着色器不在连接任何程序对象时，他的内存将会被释放。
    glDeleteShader(vertexShader);
    glDeleteShader(fragShader);
    return program;
}


/// 程序链接
-(void)linkProgram:(GLuint)program {
    //8. 程序链接
    glLinkProgram(program);
    GLint linkStatus;
    //获取编译状态
    glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLchar info[512];
        glGetProgramInfoLog(program, sizeof(info), 0, &info[0]);
        NSString *message = [NSString stringWithUTF8String: info];
        NSLog(@"Program Link Error:%@",message);
        return;
    }
    NSLog(@"Program Link Success!");
    
    //9.使用program
    glUseProgram(program);
}

@end
