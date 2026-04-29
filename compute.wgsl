
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

//=====================================================================================
//=====================================================================================

// Bindings
@group(0) @binding(0) var<storage, read> boidsIn: array<Boid>;
@group(0) @binding(1) var<storage, read_write> boidsOut: array<Boid>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

//=====================================================================================
//=====================================================================================

// Helper Functions

// Calculate the shortest distance between two points (3D)
fn torodialDistance(a: vec3f, b: vec3f) -> vec3f {
    var diff = b - a;

    // Wrap around the edges
    if (diff.x > uniforms.width * 0.5) { diff.x -= uniforms.width; }
    if (diff.x < -uniforms.width * 0.5) { diff.x += uniforms.width; }
    if (diff.y > uniforms.height * 0.5) { diff.y -= uniforms.height; }
    if (diff.y < -uniforms.height * 0.5) { diff.y += uniforms.height; }
    if (diff.z > uniforms.depth * 0.5) { diff.z -= uniforms.depth; }
    if (diff.z < -uniforms.depth * 0.5) { diff.z += uniforms.depth; }

    return diff;
}

// Limit a vector's magnitude to the max value (3D)
fn limit(vec: vec3f, max: f32) -> vec3f {
    let lengthSq = dot(vec, vec);
    if (lengthSq > max * max) {
        return normalize(vec) * max;
    }
    return vec;
}

// Wrap a position around the canvas edges (3D)
fn wrapPosition(pos: vec3f) -> vec3f {
    var p = pos;
    if (p.x < 0.0) { p.x += uniforms.width; }
    if (p.x >= uniforms.width) { p.x -= uniforms.width; }
    if (p.y < 0.0) { p.y += uniforms.height; }
    if (p.y >= uniforms.height) { p.y -= uniforms.height; }
    if (p.z < 0.0) { p.z += uniforms.depth; }
    if (p.z >= uniforms.depth) { p.z -= uniforms.depth; }
    return p;
}

// Convert 2d mouse coordinate to its 3d direction ray 
fn getMouseRay() -> vec3f {
    
    // Camera set up
    let cameraPos = vec3f(uniforms.cameraPosX, uniforms.cameraPosY, uniforms.cameraPosZ);
    let cameraTarget = vec3f(uniforms.cameraTargetX, uniforms.cameraTargetY, uniforms.cameraTargetZ);
    let forward = normalize(cameraTarget - cameraPos);
    let worldUp = vec3f(0.0, 1.0, 0.0);
    let right = normalize(cross(worldUp, forward) + vec3f(0.0001, 0.0, 0.0001));
    let up = cross(forward, right);
    
    // Get the 3d direction ray from the camera to the mouse
    let fov = 1.5;
    let aspect = uniforms.width / uniforms.height;
    let rd = normalize(
        forward 
        + (uniforms.mouseX - 0.5) * right * fov * aspect 
        + (0.5 - uniforms.mouseY) * up * fov
    );
    return rd;
}

// Get the distance from a point to a ray
// Used to get the distance between the boid and the mouse array
fn distToRay(point: vec3f, rayOrigin: vec3f, rayDir: vec3f) -> f32 {
    let v = point - rayOrigin;
    let t = dot(v, rayDir);                
    let closest = rayOrigin + rayDir * t;  
    return length(point - closest);         
}

// Get the closest point on a ray to a given point
fn closestPointOnRay(point: vec3f, rayOrigin: vec3f, rayDir: vec3f) -> vec3f {
    let v = point - rayOrigin;
    let t = dot(v, rayDir);
    return rayOrigin + rayDir * t;
}

//=====================================================================================
//=====================================================================================

// Main Function
@compute @workgroup_size(64)
fn cs(@builtin(global_invocation_id) global_id: vec3u) {
    let idx = global_id.x;

    // Limit the number of boids
    if (idx >= u32(uniforms.numBoids)) {
        return;
    }

    let currentBoid = boidsIn[idx];

    // Force vectors and counters
    var separationForce = vec3f(0.0, 0.0, 0.0);
    var alignmentForce = vec3f(0.0, 0.0, 0.0);
    var cohesionForce = vec3f(0.0, 0.0, 0.0);
    var separationCount = 0.0;
    var alignmentCount = 0.0;
    var cohesionCount = 0.0;

    // Check every neighbor
    for (var i = 0u; i < u32(uniforms.numBoids); i++) {

        // Skip self
        if (i == idx) {
            continue;
        }

        // Check distance between boids
        let otherBoid = boidsIn[i];
        let diff = torodialDistance(currentBoid.pos, otherBoid.pos);
        let dist = length(diff);

        // Separation
        if (dist < uniforms.separationRadius && dist > 0.0) {
            separationForce += -normalize(diff) / dist;
            separationCount += 1.0;
        }

        // Alignment
        if (dist < uniforms.alignmentRadius) {
            alignmentForce += otherBoid.vel;
            alignmentCount += 1.0;
        }

        // Cohesion
        if (dist < uniforms.cohesionRadius) {
            cohesionForce += diff;
            cohesionCount += 1.0;
        }

    }

    // Process Separation
    if (separationCount > 0.0) {
        separationForce /= separationCount;
        separationForce = normalize(separationForce) * uniforms.maxSpeed;
        separationForce -= currentBoid.vel;
        separationForce = limit(separationForce, uniforms.maxForce);
    }

    // Process Alignment
    if (alignmentCount > 0.0) {
        alignmentForce /= alignmentCount;
        alignmentForce = normalize(alignmentForce) * uniforms.maxSpeed;
        alignmentForce -= currentBoid.vel;
        alignmentForce = limit(alignmentForce, uniforms.maxForce);
    }

    // Process Cohesion
    if (cohesionCount > 0.0) {
        cohesionForce /= cohesionCount;
        cohesionForce = normalize(cohesionForce) * uniforms.maxSpeed;
        cohesionForce -= currentBoid.vel;
        cohesionForce = limit(cohesionForce, uniforms.maxForce);
    }

    // Apply weight to new velocity
    var newVel = currentBoid.vel;
    newVel += separationForce * uniforms.separationWeight;
    newVel += alignmentForce * uniforms.alignmentWeight;
    newVel += cohesionForce * uniforms.cohesionWeight;

    // 3D Mouse interaction
    if (uniforms.mouseActive > 0.5) {

        // Get the camera
        let cameraPos = vec3f(uniforms.cameraPosX, uniforms.cameraPosY, uniforms.cameraPosZ);
        
        // Get the ray from the camera to the mouse
        let rayDir = getMouseRay();

        // Get the distance of the current boid to the mouse array 
        let dist = distToRay(currentBoid.pos, cameraPos, rayDir);
        
        // The range of the mouse' area of effect
        let mouseRadius = 250.0;

        // If the boid is close to the mouse
        if (dist < mouseRadius && dist > 0.0) {

            // Find the ray from the boid to the mouse ray 
            let closest = closestPointOnRay(currentBoid.pos, cameraPos, rayDir);
            let toRay = closest - currentBoid.pos;
            let dir = normalize(toRay + vec3f(0.0001));

            var mouseForce = vec3f(0.0);
            let strength = 1.0 - (dist / mouseRadius);

            // Repel
            if (uniforms.mouseMode < 0.5) {
                mouseForce = -dir * strength * 800.0;
            }
            // Attract
            else {
                mouseForce = dir * strength * 800.0;
            }

            newVel += mouseForce;
        }
    }

    newVel = limit(newVel, uniforms.maxSpeed);

    // Update position
    var newPos = currentBoid.pos + newVel * uniforms.deltaTime;
    newPos = wrapPosition(newPos);

    boidsOut[idx] = Boid(newPos, newVel);

}