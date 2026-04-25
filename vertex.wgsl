
// Structs
struct Boid {
    pos: vec2f,
    vel: vec2f,
};
struct Uniforms {
    time: f32,
    deltaTime: f32,
    width: f32,
    height: f32,
    numBoids: f32,
    maxSpeed: f32,
    maxForce: f32,
    separationRadius: f32,
    alignmentRadius: f32,
    cohesionRadius: f32,
    separationWeight: f32,
    alignmentWeight: f32,
    cohesionWeight: f32,
    mouseX: f32,
    mouseY: f32,
    mouseActive: f32,
    mouseMode: f32,
    pad1: f32,
    pad2: f32,
    pad3: f32,
};
struct VertexInput {
    @builtin(vertex_index) vertexIndex: u32,
    @builtin(instance_index) instanceIndex: u32,
};
struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) vColor: vec3f,
};

// Bindings
@group(0) @binding(0) var<storage, read> boids: array<Boid>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;

// Rotation Matrix
fn rotate2d(angle: f32) -> mat2x2f {
    let c = cos(angle);
    let s = sin(angle);
    return mat2x2f(c, s, -s, c);
}

// Main Function
@vertex
fn vs(input: VertexInput) -> VertexOutput {

    let boid = boids[input.instanceIndex];

    // Triangle vertices centered at the origin
    var pos = array<vec2f, 3>(
        vec2f(-0.5, -0.3),
        vec2f(-0.5, 0.3),
        vec2f(0.5, 0.0),
    );

    // Scale the triangle
    let size = 8.0;
    var vertexPos = pos[input.vertexIndex] * size;

    // Rotate to the velocity
    let angle = atan2(boid.vel.y, boid.vel.x);
    let rotMatrix = rotate2d(angle);
    vertexPos = rotMatrix * vertexPos;

    // Translate to boid position
    vertexPos += boid.pos;

    // Conver to clip space
    let clipX = (vertexPos.x / uniforms.width) * 2.0 - 1.0;
    let clipY = 1.0 - (vertexPos.y / uniforms.height) * 2.0;

    // Color based on speed
    let speed = length(boid.vel) / uniforms.maxSpeed;
    let color = mix(
        vec3f(0.2, 0.5, 1.0),   // Slow boid: blue
        vec3f(1.0, 0.3, 0.1),   // Fast boid: orange red
        speed
    );

    // Return position and color 
    var output: VertexOutput;
    output.position = vec4f(clipX, clipY, 0.0, 1.0);
    output.vColor = color;
    return output;

}