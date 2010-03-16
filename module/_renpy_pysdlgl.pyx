# This file contains bindings to integrate pygame (SDL) and OpenGL.

cdef extern from "pygame/pygame.h":
    struct SDL_Surface:
        int w
        int h
        int pitch
        void *pixels
 
    SDL_Surface *PySurface_AsSurface(object)

    
cdef extern from "GL/glew.h":
    ctypedef unsigned int    GLenum
    ctypedef unsigned char   GLboolean
    ctypedef unsigned int    GLbitfield
    ctypedef void            GLvoid
    ctypedef signed char     GLbyte
    ctypedef short           GLshort
    ctypedef int             GLint
    ctypedef unsigned char   GLubyte
    ctypedef unsigned short  GLushort
    ctypedef unsigned int    GLuint
    ctypedef int             GLsizei
    ctypedef float           GLfloat
    ctypedef float           GLclampf
    ctypedef double          GLdouble
    ctypedef double          GLclampd


    GLenum GLEW_OK
    GLenum glewInit()    
    GLubyte *glewGetErrorString(GLenum)

    int GL_UNPACK_ROW_LENGTH
    int GL_PACK_ROW_LENGTH
     
    void glPixelStorei(
        GLint pname,
        GLint param)

    int GL_TEXTURE_2D
    int GL_RGBA8
    int GL_RGBA
    int GL_BGRA
    int GL_ALPHA
    int GL_UNSIGNED_BYTE
          
    void glTexImage2D(
        GLenum target,
        GLint level,
        GLint internalformat, 
        GLsizei width,
        GLsizei height,
        GLint border,
        GLenum format,
        GLenum type,
        void *pixels)

    void glTexSubImage2D(
        int target,
        int level,
        int xoffset,
        int yoffset,
        int width,
        int height,
        int format,
        int type,
        void *pixels)

    GLenum GL_TEXTURE0_ARB
    GLenum GL_TEXTURE1_ARB
    GLenum GL_TEXTURE2_ARB

    GLenum GL_TRIANGLE_STRIP
    
    void glMultiTexCoord2fARB(GLenum, GLfloat, GLfloat)
    void glVertex2f(GLfloat, GLfloat)
    void glBegin(GLenum)
    void glEnd()
    void glActiveTextureARB(GLenum)
    void glBindTexture(GLenum, GLuint texture)

    GLubyte  *glGetString(GLenum)

    void glReadPixels(
        GLint,
        GLint,
        GLsizei,
        GLsizei,
        GLenum,
        GLenum,
        void *)
    
    
def init_glew():
    err = glewInit()

    if err != GLEW_OK:
        raise Exception("Glew init failed: %s" % <char *> glewGetErrorString(err))

    
def premultiply(
    object pysurf,
    int x,
    int y,
    int w,
    int h):
    
    """
    Creates a string containing the premultiplied image data for
    for the (x, y, w, h) box inside pysurf.
    """

    # Adjust the alpha if we have an alpha-free image.
    cdef unsigned char alpha_and
    cdef unsigned char alpha_or
    
    if pysurf.get_masks()[3]:
        alpha_and = 255
        alpha_or = 0
    else:
        alpha_and = 0
        alpha_or = 255

    # Allocate an uninitialized string.
    cdef unsigned char *null = NULL
    rv = null[:w*h*4]
    
    # Out is where we put the output.
    cdef unsigned char *out = rv
    
    # The pixels in the source image.
    cdef unsigned char *pixels = NULL
    cdef SDL_Surface *surf

    # Pointer to the current pixel.
    cdef unsigned char *p

    # Pointer to the current output pixel.
    cdef unsigned char *op
    
    # Pointer to the row end.
    cdef unsigned char *pend

    # alpha value.
    cdef unsigned int a
    
    
    surf = PySurface_AsSurface(pysurf)
    pixels = <unsigned char *> surf.pixels

    pixels += y * surf.pitch
    pixels += x * 4

    op = out
    
    for y from 0 <= y < h:
        p = pixels + y * surf.pitch
        pend = p + w * 4

        while p < pend:
            a = (p[3] & alpha_and) | alpha_or

            op[0] = p[0] * a / 255
            op[1] = p[1] * a / 255
            op[2] = p[2] * a / 255
            op[3] = a
            
            p += 4
            op += 4

    return rv


def load_premultiplied(data, width, height, update):

    cdef char *pixels

    if data:
        pixels = data
    else:
        pixels = NULL
    

    if update:
        glTexSubImage2D(
            GL_TEXTURE_2D,
            0,
            0,
            0,
            width,
            height,
            GL_BGRA,
            GL_UNSIGNED_BYTE,
            pixels)
        
    else:
        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RGBA,
            width,
            height,
            0,
            GL_BGRA,
            GL_UNSIGNED_BYTE,
            pixels)


def store_framebuffer(
    object pysurf,
    ):
    
    """
    This loads the supplied pygame surface into the numbered
    texture. The created texture will be of size (width, height),
    and at position (xoffset, yoffset) relative to the containing
    image. 
    """
    cdef unsigned char *pixels = NULL
    cdef SDL_Surface *surf
        
    surf = PySurface_AsSurface(pysurf)
    pixels = <unsigned char *> surf.pixels

    glPixelStorei(GL_PACK_ROW_LENGTH, surf.pitch / 4)

    glReadPixels(
        0,
        0,
        surf.w,
        surf.h,
        GL_BGRA,
        GL_UNSIGNED_BYTE,
        pixels)

    
def draw_rectangle(
    float sx,
    float sy,
    float x,
    float y,
    float w,
    float h,
    transform,
    tex0, int tex0x, int tex0y,
    tex1, int tex1x, int tex1y,
    tex2, int tex2x, int tex2y):

    """
    This draws a rectangle (textured with up to four textures) to the
    screen.
    """

    # Do we have the given texture?
    cdef int has_tex0, has_tex1, has_tex2

    # Texture coordinates.
    cdef float t0u0, t0v0, t0u1, t0v1
    cdef float t1u0, t1v0, t1u1, t1v1
    cdef float t2u0, t2v0, t2u1, t2v1    
    
    # Pull apart the transform.
    cdef float xdx = transform.xdx
    cdef float xdy = transform.xdy
    cdef float ydx = transform.ydx
    cdef float ydy = transform.ydy

    # Transform the vertex coordinates to screen-space.
    cdef float x0 = (x + 0) * xdx + (y + 0) * xdy + sx
    cdef float y0 = (x + 0) * ydx + (y + 0) * ydy + sy

    cdef float x1 = (x + w) * xdx + (y + 0) * xdy + sx
    cdef float y1 = (x + w) * ydx + (y + 0) * ydy + sy

    cdef float x2 = (x + 0) * xdx + (y + h) * xdy + sx
    cdef float y2 = (x + 0) * ydx + (y + h) * ydy + sy

    cdef float x3 = (x + w) * xdx + (y + h) * xdy + sx
    cdef float y3 = (x + w) * ydx + (y + h) * ydy + sy

    # Compute the texture coordinates, and set up the textures.
    cdef float xadd, yadd, xmul, ymul

    if tex0 is not None:

        has_tex0 = 1

        glActiveTextureARB(GL_TEXTURE0_ARB)
        glBindTexture(GL_TEXTURE_2D, tex0.number)
        
        xadd = tex0.xadd
        yadd = tex0.yadd
        xmul = tex0.xmul
        ymul = tex0.ymul
        
        t0u0 = xadd + xmul * (tex0x + 0)
        t0u1 = xadd + xmul * (tex0x + w)
        t0v0 = yadd + ymul * (tex0y + 0)
        t0v1 = yadd + ymul * (tex0y + h)

    else:
        has_tex0 = 0
    
    if tex1 is not None:

        has_tex1 = 1

        glActiveTextureARB(GL_TEXTURE1_ARB)
        glBindTexture(GL_TEXTURE_2D, tex1.number)
        
        xadd = tex1.xadd
        yadd = tex1.yadd
        xmul = tex1.xmul
        ymul = tex1.ymul
        
        t1u0 = xadd + xmul * (tex1x + 0)
        t1u1 = xadd + xmul * (tex1x + w)
        t1v0 = yadd + ymul * (tex1y + 0)
        t1v1 = yadd + ymul * (tex1y + h)

    else:
        has_tex1 = 0

    if tex2 is not None:

        has_tex2 = 1

        glActiveTextureARB(GL_TEXTURE2_ARB)
        glBindTexture(GL_TEXTURE_2D, tex2.number)
        
        xadd = tex2.xadd
        yadd = tex2.yadd
        xmul = tex2.xmul
        ymul = tex2.ymul
        
        t2u0 = xadd + xmul * (tex2x + 0)
        t2u1 = xadd + xmul * (tex2x + w)
        t2v0 = yadd + ymul * (tex2y + 0)
        t2v1 = yadd + ymul * (tex2y + h)

    else:
        has_tex2 = 0


    # Now, actually draw the textured rectangle.

    glBegin(GL_TRIANGLE_STRIP)

    if has_tex0:
        glMultiTexCoord2fARB(GL_TEXTURE0_ARB, t0u0, t0v0)
    if has_tex1:
        glMultiTexCoord2fARB(GL_TEXTURE1_ARB, t1u0, t1v0)
    if has_tex2:
        glMultiTexCoord2fARB(GL_TEXTURE2_ARB, t2u0, t2v0)
    glVertex2f(x0, y0)

    if has_tex0:
        glMultiTexCoord2fARB(GL_TEXTURE0_ARB, t0u1, t0v0)
    if has_tex1:
        glMultiTexCoord2fARB(GL_TEXTURE1_ARB, t1u1, t1v0)
    if has_tex2:
        glMultiTexCoord2fARB(GL_TEXTURE2_ARB, t2u1, t2v0)
    glVertex2f(x1, y1)

    if has_tex0:
        glMultiTexCoord2fARB(GL_TEXTURE0_ARB, t0u0, t0v1)
    if has_tex1:
        glMultiTexCoord2fARB(GL_TEXTURE1_ARB, t1u0, t1v1)
    if has_tex2:
        glMultiTexCoord2fARB(GL_TEXTURE2_ARB, t2u0, t2v1)
    glVertex2f(x2, y2)

    if has_tex0:
        glMultiTexCoord2fARB(GL_TEXTURE0_ARB, t0u1, t0v1)
    if has_tex1:
        glMultiTexCoord2fARB(GL_TEXTURE1_ARB, t1u1, t1v1)
    if has_tex2:
        glMultiTexCoord2fARB(GL_TEXTURE2_ARB, t2u1, t2v1)
    glVertex2f(x3, y3)
    
    glEnd()


def get_string(name):
    return <char *> glGetString(name)
