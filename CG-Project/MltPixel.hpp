#pragma once

/**
 * @file MltPixel.hpp
 * @author
 * @brief Contains the data structures and shader invocation functions
 * @version 0.1
 * @date 2022-12-14
 * 
 * @copyright Copyright (c) 2022
 * 
 */

#include <atomic>
#include <list>
#include <random>
#include <set>

#include "glm/glm.hpp"

#define NUM_HITS 10
#define SAMPLES 1
#define MUTATIONS 100

#define ivec2 glm::ivec2
#define vec2 glm::highp_f32vec2
#define vec3 glm::highp_f32vec3
#define vec4 glm::highp_f32vec4
#define mat3 glm::highp_f32mat3
#define mat4 glm::highp_f32mat4

/**
 * @brief Struct for a single Ray
 * 
 */
struct Ray
{
	vec3 dir;
	vec3 nrg;
	vec3 org;
};

/**
 * @brief Struct for a single hit by a Ray on any surface
 * 
 */
struct RayHit
{
	double dist;
	double smoothness;
	bool skybox;
	vec3 albedo;
	vec3 emission;
	vec3 norm;
	vec3 pos;
	vec3 specular;
};

/**
 * @brief Struct containing a single node of a Path
 * 
 */
struct PathNode
{
	RayHit hit;
	Ray ray;
	vec3 rslt;
	int nextA;
	int nextM;
};

/**
 * @brief Struct containing a single Path
 * 
 */
struct Path 
{
	PathNode nodes[NUM_HITS];
};

/**
 * @brief Struct containing a single Sphere surface
 * 
 */
struct Sph
{
	vec3 pos;
	double rad;
	vec3 albedo;
	vec3 specular;
	double smoothness;
	vec3 emission;
	Sph(vec3 pos, float rad, vec3 albedo, vec3 specular, double smoothness, vec3 emission) : pos(pos), rad(rad), albedo(albedo), specular(specular), smoothness(smoothness), emission(emission)
	{}
};

/**
 * @brief Custom vec4 for which we define <operator to store vec4 in std::set
 * 
 */
struct mvec4 
{
	vec4 colour;
	mvec4(vec4 color) : colour(colour)
	{}
};

/**
 * @brief Shoots the ray and returns the ray hit point.
 * 
 * @param ray Ray to be shot
 * @return RayHit Point which the Ray hits
 */
RayHit Trc(Ray ray);

/**
 * @brief Updates the ray based on the ray hit for the next raycast by random sampling
 * the given distribution and returns the color for the given ray and ray hit.
 * 
 * @param ray Ray to be updated
 * @param hit RayHit to be used for updating the ray
 * @param e2 Random Generating Engine
 * @param dist Random Distribution
 * @return vec3 Color result for the given ray and ray hit.
 */
vec3 Shd(Ray& ray, RayHit hit, std::mt19937& e2, std::uniform_real_distribution<double>& dist);
void drawPixel(int x, int y, int imgWid, int imgHt, vec4* frmBuff, std::atomic<int>& done);