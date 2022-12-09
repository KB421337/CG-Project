#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <windows.h>

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtx/string_cast.hpp"
#include "glm/gtc/type_ptr.hpp"
#include "stb_image.h"

using namespace std;

string shdrSrc(string path) 
{
    ifstream f(path);
    stringstream buffer;
    buffer<<f.rdbuf();
    f.close();
    return buffer.str();
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
            cout<<"Cubemap tex failed to load at path: "<<faces[i]<<"\n";
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

int main()
{
    GLFWwindow* window;

    /* Initializing the library */
    if (!glfwInit())
        return -1;

    /* Creating a windowed mode window and its OpenGL context */
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);
    window = glfwCreateWindow(640, 480, "Path Tracing", NULL, NULL);
    if (!window)
    {
        glfwTerminate();
        return -1;
    }

    /* Making the window's context current */
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    /* Checking if GLAD initialized successfully */
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) 
    {
		cout<<"GLAD failed to initialize successfully!! \n";
		return -1;
	}


    int width = 900;
    int height = 900;
    // Texture definition

        int tw = width, th = height;
    GLuint tex_out;
    glGenTextures(1, &tex_out);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, tex_out);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, tw, th, 0, GL_RGBA, GL_FLOAT, NULL);
    glBindImageTexture(0, tex_out, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

    glBindTexture(GL_TEXTURE_2D, 0);

    string shaderSrc;

    shaderSrc = shdrSrc("shader.vert");
    const char* vertSrc;
    vertSrc = shaderSrc.c_str();

    shaderSrc = shdrSrc("shader.frag");
    const char* fragSrc;
    fragSrc = shaderSrc.c_str();

    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertSrc, NULL);
    glCompileShader(vertexShader);
    int success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success) 
    {
        cout<<"Vertex error" << endl;
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        cout << infoLog << endl;
    }

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragSrc, NULL);
    glCompileShader(fragmentShader);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        cout << "Fragment error" << endl;
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        cout << infoLog << endl;
    }

    GLuint quadProgram = glCreateProgram();
    glAttachShader(quadProgram, vertexShader);
    glAttachShader(quadProgram, fragmentShader);
    glLinkProgram(quadProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    float vertices[] =
    {
        1,1,0,1,1,
        1,-1,0,1,0,
        -1,1,0,0,1,
        1,-1,0,1,0,
        -1,-1,0,0,0,
        -1,1,0,0,1
    };

    //Buffers
    GLuint VAO, VBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5*sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5*sizeof(float), (void*)(3*sizeof(float)));
    glEnableVertexAttribArray(1);

    float mesh[] =
    {
        1,1,0,0,
        1,0,0,0,
        0,1,0,0,
        1,0,0,0,
        0,0,0,0,
        0,1,0,0,
    };

    GLuint meshBlock;
    glGenBuffers(1, &meshBlock);
    glBindBuffer(GL_UNIFORM_BUFFER, meshBlock);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(mesh), NULL, GL_STATIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, meshBlock);

    vector<string> faces
    {
            "skybox/r.jpg",
            "skybox/l.jpg",
            "skybox/u.jpg",
            "skybox/d.jpg",
            "skybox/f.jpg",
            "skybox/b.jpg"
    };
    unsigned int cubemapTexture = loadCubemap(faces);

    //////////////////////
    float iter;
    glm::mat4 rot_matrix = glm::mat4(1.0f);
    ////////////////////////

    float aperture[4] =
    {
        0.0f, 0.0f, 10.0f, 1.0f
    };
    float seed = 0.5f;
    iter = 0.0f;
    rot_matrix = glm::rotate(rot_matrix, glm::radians(5.0f), glm::vec3(0.0, 1.0, 0.0));
    //Loop

    /* Looping until the user closes the window */
    while (!glfwWindowShouldClose(window))
    {
        glUseProgram(rayProgram);

        int sizeLoc = glGetUniformLocation(rayProgram, "size");
        //		glUniform1f(sizeLoc, sizeof(mesh) / 4);
        int seedLoc = glGetUniformLocation(rayProgram, "seed");
        glUniform1f(seedLoc, seed);
        seed += 3.1415f;
        int appertureLoc = glGetUniformLocation(rayProgram, "aperture");
        glUniform4fv(appertureLoc, 1, aperture);

        int rotateLoc = glGetUniformLocation(rayProgram, "rotate_matrix");
        glUniformMatrix4fv(rotateLoc, 1, GL_FALSE, glm::value_ptr(rot_matrix));
        glBindTexture(GL_TEXTURE_CUBE_MAP, cubemapTexture);
        glDispatchCompute((GLuint)tw, (GLuint)th, 1);

        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        //		glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(quadProgram);
        glBindVertexArray(VAO);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, tex_out);
        int iterLoc = glGetUniformLocation(quadProgram, "iter");
        glUniform1f(iterLoc, iter);
        iter += 1.0f;
        glEnable(GL_BLEND);
        glBlendEquation(GL_FUNC_ADD);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glBindBuffer(GL_UNIFORM_BUFFER, meshBlock);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(mesh), mesh);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);

        glUseProgram(0);

        /* Swapping front and back buffers */
        glfwSwapBuffers(window);

        /* Polling for and processing events */
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;
}