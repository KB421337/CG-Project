// IS F311: Computer Graphics - Project   
// - Anish Kacham          | 2019A7PS0091H
// - Arjav Garg            | 2019A7PS0068H
// - Kaustubh Bhanj        | 2019A7PS0009H
// - Kevin K.Biju          | 2019A7PS0045H
// - Nishith Kumar         | 2020A7PS0157H
// - Shreyas Gupta         | 2019A7PS0121H

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <thread>
#include <windows.h>

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtx/string_cast.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "stb_image.h"

#include "MltPixel.hpp"

#ifdef _MSC_VER
#define ASSERT(x) if (!(x)) __debugbreak();
#else
#define ASSERT(x) assert(x)
#endif
#define GlCall(x) GlClearError(); x; ASSERT(GlLogCall(#x, __FILE__, __LINE__))

using namespace std;

void GlClearError()
{
    while (glGetError() != GL_NO_ERROR);
}

bool GlLogCall(const char* func, const char* file, int line)
{
    if (GLenum error = glGetError())
    {
        cout << "[OpenGL Error] (" << error << "): " << func << " " << file << ":" << line << "\n";
        return false;
    }
    return true;
}

string shdrSrc(string path)
{
    ifstream f(path);
    stringstream buff;
    buff << f.rdbuf();
    f.close();
    string s = buff.str();
    return s;
}

unsigned int loadCubemap(vector<string> faces)
{
    unsigned int texId;
    int w, h, nrChans;
    glGenTextures(1, &texId);
    glBindTexture(GL_TEXTURE_CUBE_MAP, texId);
    for (unsigned int i = 0; i < faces.size(); i++)
    {
        unsigned char* data = stbi_load(faces[i].c_str(), &w, &h, &nrChans, 0);
        if (data)
        {
            glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB, w, h, 0, GL_RGB, GL_UNSIGNED_BYTE, data);
            stbi_image_free(data);
        }
        else
        {
            cout << "Cubemap tex failed to load at path: " << faces[i] << "\n";
            stbi_image_free(data);
        }
    }
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    return texId;
}

void runXLoop(int y, int imgWidth, int imgHeight, vec4* frameBuff, atomic<int>& done)
{
    for (int x = 0; x < imgWidth; x++) {
        drawPixel(x, y, imgWidth, imgHeight, frameBuff, done);
    }
}

int main()
{
    GLFWwindow* window;
    if (!glfwInit())
        return -1;
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
    window = glfwCreateWindow(900, 900, "Metropolis Light Transport", NULL, NULL);
    if (!window)
    {
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) 
    {
		cout << "GLAD failed to initialize successfully!! \n";
		return -1;
	}
    const int texWid = 900, texHt = 900;
    GLuint texOut;
    glGenTextures(1, &texOut);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texOut);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, texWid, texHt, 0, GL_RGBA, GL_FLOAT, NULL);
    glBindImageTexture(GL_TEXTURE0, texOut, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);
    glBindTexture(GL_TEXTURE_2D, 0);
    int wrkGrpCnt[3], wrkGrpInv;
    for (int i = 0; i < 3; i++) 
        glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, i, &wrkGrpCnt[i]);
    cout << "Global work group counts x:" << wrkGrpCnt[0] << " y: " << wrkGrpCnt[1] << " z: " <<  wrkGrpCnt[2] << "\n";
    glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &wrkGrpInv);
    cout << "Local work group invocations: " << wrkGrpInv << "\n";
    int success;
    char infoLog[512];
    string shaderSrc = shdrSrc("shader.vert");
    const char* vertSrc = shaderSrc.c_str();
    GLuint vertShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertShader, 1, &vertSrc, NULL);
    glCompileShader(vertShader);
    glGetShaderiv(vertShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        cout << "ERROR: Vertex Shader compilation failed!! \n";
        glGetShaderInfoLog(vertShader, 512, NULL, infoLog);
        cout << infoLog << "\n";
    }
    shaderSrc = shdrSrc("shader.frag");
    const char* fragSrc = shaderSrc.c_str();
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShader, 1, &fragSrc, NULL);
    glCompileShader(fragShader);
    glGetShaderiv(fragShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        cout << "ERROR: Fragment Shader compilation failed!! \n";
        glGetShaderInfoLog(fragShader, 512, NULL, infoLog);
        cout << infoLog << "\n";
    }
    GLuint vnfProg = glCreateProgram();
    glAttachShader(vnfProg, vertShader);
    glAttachShader(vnfProg, fragShader);
    glLinkProgram(vnfProg);
    glGetProgramiv(vnfProg, GL_LINK_STATUS, &success);
    if (!success)
    {
        cout << "ERROR: VertFrag Shader linking failed!! \n";
        glGetProgramInfoLog(vnfProg, 512, NULL, infoLog);
        cout << infoLog << "\n";
    }
    glDeleteShader(vertShader);
    glDeleteShader(fragShader);
    float verts[] =
    {
         1,  1,  0,  1,  1,
         1, -1,  0,  1,  0,
        -1,  1,  0,  0,  1,
         1, -1,  0,  1,  0,
        -1, -1,  0,  0,  0,
        -1,  1,  0,  0,  1
    };
    GLuint VAO, VBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5*sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5*sizeof(float), (void*)(3*sizeof(float)));
    glEnableVertexAttribArray(1);
    float mesh[] =
    {
        1, 1, 0, 0,
        1, 0, 0, 0,
        0, 1, 0, 0,
        1, 0, 0, 0,
        0, 0, 0, 0,
        0, 1, 0, 0
    };
    GLuint meshBlock;
    glGenBuffers(1, &meshBlock);
    glBindBuffer(GL_UNIFORM_BUFFER, meshBlock);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(mesh), NULL, GL_STATIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, meshBlock);
    vector<string> faces
    {
        "skybox/r.png",
        "skybox/l.png",
        "skybox/u.png",
        "skybox/d.png",
        "skybox/f.png",
        "skybox/b.png"
    };
    unsigned int cubemapTex = loadCubemap(faces);
    float iter = 0.0f, aperture[4] = {0.0f, 0.0f, 10.0f, 1.0f}, seed = 0.5f, float color = 0, dc = 0.01;
    vec4* frameBuff = new vec4[texWid*texHt];
    while (!glfwWindowShouldClose(window))
    {
        glFinish();
        atomic<int> done{0};
        set<mvec4> colours;
        for (int y = 0; y < texHt; y++)
        {
            thread(runXLoop, y, texWid, texHt, frameBuff, ref(done)).detach();
            cout << y << " ";
        }
        while (done != texWid*texHt)
        {
            cout << done << " ";
        }
        for (const mvec4 m : colours)
        {
            cout << m.colour.r << "," << m.colour.g << "," << m.colour.b << " ";
        }
        glUseProgram(vnfProg);
        glBindVertexArray(VAO);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texOut);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, texWid, texHt, 0, GL_RGBA, GL_FLOAT, frameBuff);
        int iterLoc = glGetUniformLocation(vnfProg, "iter");
        iter += 1.0f;
        glEnable(GL_BLEND);
        glBlendEquation(GL_FUNC_ADD);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        glBindBuffer(GL_UNIFORM_BUFFER, meshBlock);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(mesh), mesh);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);
        glUseProgram(0);
        glfwSwapBuffers(window);
        glfwPollEvents();
        cout << "Rendered frame " << iter << "\n";
    }
    while (1);
    glfwTerminate();
    return 0;
}