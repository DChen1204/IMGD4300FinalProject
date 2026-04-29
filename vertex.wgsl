
// Structs
struct Boid {
    pos: vec3f,
    vel: vec3f,
};
struct Uniforms {
    time: f32,
    deltaTime: f32,
    width: f32,
    height: f32,
    depth: f32,
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
    cameraPosX: f32,
    cameraPosY: f32,
    cameraPosZ: f32,
    cameraTargetX: f32,
    cameraTargetY: f32,
    cameraTargetZ: f32,
};
struct VertexInput {
    @builtin(vertex_index) vertexIndex: u32,
    @builtin(instance_index) instanceIndex: u32,
};
struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) vColor: vec3f,
    @location(1) vNormal: vec3f,
    @location(2) vWorldPos: vec3f,
};

//=====================================================================================
//=====================================================================================

// Bindings
@group(0) @binding(0) var<storage, read> boids: array<Boid>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;

//=====================================================================================
//=====================================================================================

// View matrix (world space -> camera space)
fn lookAt(eye: vec3f, lookAt: vec3f, up: vec3f) -> mat4x4f {
    let forward = normalize(lookAt - eye);
    let right = normalize(cross(forward, up));
    let newUp = cross(right, forward);

    return mat4x4f(
        vec4f(right.x, newUp.x, -forward.x, 0.0),
        vec4f(right.y, newUp.y, -forward.y, 0.0),
        vec4f(right.z, newUp.z, -forward.z, 0.0),
        vec4f(-dot(right, eye), -dot(newUp, eye), dot(forward, eye), 1.0)
    );
}

// Projection matrix (camera space -> clip space)
fn perspective(fov: f32, aspect: f32, near: f32, far: f32) -> mat4x4f {
    let f = 1.0 / tan(fov * 0.5);
    let rangeInv = 1.0 / (near - far);

    return mat4x4f(
        vec4f(f / aspect, 0.0, 0.0, 0.0),
        vec4f(0.0, f, 0.0, 0.0),
        vec4f(0.0, 0.0, (near + far) * rangeInv, -1.0),
        vec4f(0.0, 0.0, near * far * rangeInv * 2.0, 0.0)
    );
}

// Rotation Matrix (align boid with velocity direction)
fn rotate(velocity: vec3f) -> mat3x3f {
    let forward = normalize(velocity);
    let worldUp = vec3f(0.0, 1.0, 0.0);
    let right = normalize(cross(worldUp, forward) + vec3f(0.0001, 0.0, 0.0001));
    let up = cross(forward, right);

    return mat3x3f(
        right,
        up,
        forward
    );
}

//=====================================================================================
//=====================================================================================

// Main Function
@vertex
fn vs(input: VertexInput) -> VertexOutput {

    let boid = boids[input.instanceIndex];

    // 3D bird-like shape
    var pos = array<vec3f, 4>(
        vec3f(0.0, 0.0, 1.0),
        vec3f(-0.5, 0.3, -0.5),
        vec3f(0.5, 0.3, -0.5),
        vec3f(0.0, -0.2, -0.5),
    );
    var indices = array<u32, 12>(
        0u, 1u, 2u,
        0u, 2u, 3u,
        0u, 3u, 1u,
        1u, 3u, 2u,
    );

    // Scale the bird
    let size = 8.0;
    var vertexPos = pos[indices[input.vertexIndex]] * size;

    // Normals for each face
    var vertexNormal: vec3f;
    if (input.vertexIndex < 3) {
        vertexNormal = vec3f(0.0, 1.0, 0.0);
    } else if (input.vertexIndex < 6) {
        vertexNormal = vec3f(1.0, 0.0, 0.0);
    } else if (input.vertexIndex < 9) {
        vertexNormal = vec3f(-1.0, 0.0, 0.0);
    } else {
        vertexNormal = vec3f(0.0, -1.0, 0.0);
    }

    // Rotate to the velocity
    let rotMatrix = rotate(boid.vel);
    vertexPos = rotMatrix * vertexPos;
    vertexNormal = rotMatrix * vertexNormal;

    // Translate to boid position
    let worldPos = vertexPos + boid.pos;

    // Camera setup
    let cameraPos = vec3f(uniforms.cameraPosX, uniforms.cameraPosY, uniforms.cameraPosZ);
    let cameraTarget = vec3f(uniforms.cameraTargetX, uniforms.cameraTargetY, uniforms.cameraTargetZ);
    let aspect = uniforms.width / uniforms.height;
    let viewMatrix = lookAt(cameraPos, cameraTarget, vec3f(0.0, 1.0, 0.0));
    let projMatrix = perspective(1.0, aspect, 1.0, 2000.0);

    // Convert to clip space
    let clipPos = projMatrix * viewMatrix * vec4f(worldPos, 1.0);

    // Color based on speed
    let speed = length(boid.vel) / uniforms.maxSpeed;
    let color = mix(
        vec3f(0.2, 0.5, 1.0),   // Slow boid: blue
        vec3f(1.0, 0.3, 0.1),   // Fast boid: red
        speed
    );

    // Return position, color, and normal
    var output: VertexOutput;
    output.position = clipPos;
    output.vColor = color;
    output.vNormal = vertexNormal;
    output.vWorldPos = worldPos;
    return output;
}