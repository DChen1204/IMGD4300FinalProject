//===================================================================================
//===================================================================================

// Canvas and WebGPU setup
const canvas = document.querySelector("canvas");

// Resize canvas based on window size dynamically
function resizeCanvas() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
}
resizeCanvas();
window.addEventListener("resize", resizeCanvas);

// Check for WebGPU support
if (!navigator.gpu) {
    throw new Error("WebGPU is not supported on this browser.");
}

// Request a GPU adapter (WebGPU's representation of a GPU hardware device)
const adapter = await navigator.gpu.requestAdapter();
if (!adapter) {
    throw new Error("No appropriate GPUAdapter found.");
}

// Request a GPU device (main interface to the GPU hardware)
const device = await adapter.requestDevice();

// Configure the canvas context (provide textures for the code to draw into)
// Textures are objects that store image data 
const context = canvas.getContext("webgpu");
const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
context.configure({
    device: device,
    format: canvasFormat,
});

//=====================================================================================
//=====================================================================================

// Load shaders from file
async function loadShader(url) {
    const response = await fetch(url);
    return await response.text();
}
const vertexShader = await loadShader("vertex.wgsl");
const fragmentShader = await loadShader("fragment.wgsl");
const computeShader = await loadShader("compute.wgsl");

// Shader modules (compile shader code to be used by the GPU)
const computeModule = device.createShaderModule({
    label: "Compute Shader Module",
    code: computeShader,
});
const vertexModule = device.createShaderModule({
    label: "Vertex Shader Module",
    code: vertexShader,
});
const fragmentModule = device.createShaderModule({
    label: "Fragment Shader Module",
    code: fragmentShader,
});

//=====================================================================================
//=====================================================================================

// Simulation Parameters
const NUM_BOIDS = 500;
const MAX_SPEED = 300.0;
const MAX_FORCE = 3.0;
const SEPARATION_RADIUS = 35.0;
const ALIGNMENT_RADIUS = 100.0;
const COHESION_RADIUS = 100.0;
// Rule Weights
const SEPARATION_WEIGHT = 2.5;
const ALIGNMENT_WEIGHT = 1.0;
const COHESION_WEIGHT = 1.0;
// Buffer sizes
const BOID_DATA_SIZE = 4;
const UNIFORM_DATA_SIZE = 20;
// Mouse tracking
let mouseX = 0;
let mouseY = 0;
let mouseActive = 0;    // 0 = none, 1 = on
let mouseMode = 0;      // 0 = repel, 1 = attract

// Boid Data Array
const boidsData = new Float32Array(NUM_BOIDS * BOID_DATA_SIZE);
for (let i = 0; i < NUM_BOIDS; i++) {
    const idx = i * BOID_DATA_SIZE;

    // Randomize position
    boidsData[idx + 0] = Math.random() * canvas.width;
    boidsData[idx + 1] = Math.random() * canvas.height;

    // Randomize initial velocity
    const angle = Math.random() * Math.PI * 2;
    const speed = MAX_SPEED * 0.5;
    boidsData[idx + 2] = Math.cos(angle) * speed;
    boidsData[idx + 3] = Math.sin(angle) * speed;
}

// Uniform Data Array
const uniformData = new Float32Array(UNIFORM_DATA_SIZE)
uniformData[0] = 0.0;               // time
uniformData[1] = 0.0;               // deltatime
uniformData[2] = canvas.width;
uniformData[3] = canvas.height;
uniformData[4] = NUM_BOIDS;
uniformData[5] = MAX_SPEED;
uniformData[6] = MAX_FORCE;
uniformData[7] = SEPARATION_RADIUS;
uniformData[8] = ALIGNMENT_RADIUS;
uniformData[9] = COHESION_RADIUS;
uniformData[10] = SEPARATION_WEIGHT;
uniformData[11] = ALIGNMENT_WEIGHT; 
uniformData[12] = COHESION_WEIGHT;
uniformData[13] = 0.0;              // mouseX
uniformData[14] = 0.0;              // mouseY
uniformData[15] = 0.0;              // mouseActive
uniformData[16] = 0.0;              // mouseMode
// paddings
uniformData[17] = 0.0;
uniformData[18] = 0.0;
uniformData[19] = 0.0;

//=====================================================================================
//=====================================================================================

// Boid buffer
const boidBuffers = [
    device.createBuffer({
        label: "Boid Buffer A",
        size: NUM_BOIDS * BOID_DATA_SIZE * 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    }),
    device.createBuffer({
        label: "Boid Buffer B",
        size: NUM_BOIDS * BOID_DATA_SIZE * 4,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    })
]
device.queue.writeBuffer(boidBuffers[0], 0, boidsData);
device.queue.writeBuffer(boidBuffers[1], 0, boidsData);

// Uniform buffer (updated in the renderer loop)
const uniformBuffer = device.createBuffer({
    label: "Uniform Buffer",
    size: UNIFORM_DATA_SIZE * 4,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});

//=====================================================================================
//=====================================================================================

// Bind Groups layouts 
const computeBindGroupLayout = device.createBindGroupLayout({
    label: "Compute Bind Group Layout",
    entries: [
        { binding: 0, visibility: GPUShaderStage.COMPUTE, buffer: { type: "read-only-storage" }},
        { binding: 1, visibility: GPUShaderStage.COMPUTE, buffer: { type: "storage" }},
        { binding: 2, visibility: GPUShaderStage.COMPUTE, buffer: { type: "uniform" }},
    ]
});
const renderBindGroupLayout = device.createBindGroupLayout({
    label: "Render Bind Group Layout",
    entries: [
        { binding: 0, visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" }},
        { binding: 1, visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT, buffer: { type: "uniform" }},
    ]
});

// Bind groups
const computeBindGroups = [
    device.createBindGroup({
        label: "Compute Bind Group A",
        layout: computeBindGroupLayout,
        entries: [
            { binding: 0, resource: { buffer: boidBuffers[0] } },
            { binding: 1, resource: { buffer: boidBuffers[1] } },
            { binding: 2, resource: { buffer: uniformBuffer } },
        ]
    }),
    device.createBindGroup({
        label: "Compute Bind Group B",
        layout: computeBindGroupLayout,
        entries: [
            { binding: 0, resource: { buffer: boidBuffers[1] } },
            { binding: 1, resource: { buffer: boidBuffers[0] } },
            { binding: 2, resource: { buffer: uniformBuffer } },
        ]
    })
];
const renderBindGroups = [
    device.createBindGroup({
        label: "Render Bind Group A",
        layout: renderBindGroupLayout,
        entries: [
            { binding: 0, resource: { buffer: boidBuffers[0] } },
            { binding: 1, resource: { buffer: uniformBuffer } },
        ]
    }),
    device.createBindGroup({
        label: "Render Bind Group B",
        layout: renderBindGroupLayout,
        entries: [
            { binding: 0, resource: { buffer: boidBuffers[1] } },
            { binding: 1, resource: { buffer: uniformBuffer } },
        ]
    })
];

//=====================================================================================
//=====================================================================================

// Pipelines layouts
const computePipelineLayout = device.createPipelineLayout({
    label: "Compute Pipeline Layout",
    bindGroupLayouts: [computeBindGroupLayout],
});
const renderPipelineLayout = device.createPipelineLayout({
    label: "Render Pipeline Layout",
    bindGroupLayouts: [renderBindGroupLayout],
});

// Pipelines
const computePipeline = device.createComputePipeline({
    label: "Compute Pipeline",
    layout: computePipelineLayout,
    compute: {
        module: computeModule,
        entryPoint: "cs",
    }
});
const renderPipeline = device.createRenderPipeline({
    label: "Render Pipeline",
    layout: renderPipelineLayout,
    vertex: {
        module: vertexModule,
        entryPoint: "vs",
        buffers: [],
    },
    fragment: {
        module: fragmentModule,
        entryPoint: "fs",
        targets: [{
            format: canvasFormat,
        }],
    },
    primitive: {
        topology: "triangle-list",
    },
});

//=====================================================================================
//=====================================================================================

// HTML Elements

// Track mouse position
canvas.addEventListener('mousemove', (e) => {
    mouseX = e.clientX;
    mouseY = e.clientY;
});

// left click toggles between repel/attract mode
canvas.addEventListener('click', (e) => {
    if (mouseActive == 1) {
        mouseMode = 1 - mouseMode;
        updateModeLabel();
    }
});

// Toggle mouse influence on/off
const mouseToggle = document.getElementById('mouseToggle');
mouseToggle.addEventListener('click', () => {
    mouseActive = 1 - mouseActive;
    mouseToggle.classList.toggle('active');
    updateModeLabel();
})

// Update mode label
function updateModeLabel() {
    const labels = document.querySelectorAll('.control-group label');
    const modeLabel = labels[labels.length - 1];
    if (mouseActive === 0) {
        modeLabel.textContent = 'Mouse influence in OFF';
    } else if (mouseMode === 0) {
        modeLabel.textContent = 'Mode: REPEL (click to switch)';
    } else {
        modeLabel.textContent = 'Mode: ATTRACT (click to switch)';
    }
}


//=====================================================================================
//=====================================================================================

// Initial program setup 
let lastTime = 0;
let totalTime = 0;
let currentBuffer = 0;

// Render loop
function render(timestamp) {

    // Calculate time and deltaTime
    const deltaTime = lastTime ? (timestamp - lastTime) / 1000 : 0.016;
    lastTime = timestamp;
    totalTime += deltaTime;

    // Update the uniform buffer 
    uniformData[0] = totalTime;              
    uniformData[1] = deltaTime;               
    uniformData[2] = canvas.width;
    uniformData[3] = canvas.height;
    uniformData[13] = mouseX;
    uniformData[14] = mouseY;
    uniformData[15] = mouseActive;
    uniformData[16] = mouseMode;
    device.queue.writeBuffer(uniformBuffer, 0, uniformData);

    // Create a command encoder (used to record commands that will be sent to the GPU)
    const encoder = device.createCommandEncoder();

    // Run compute shader 
    const computePass = encoder.beginComputePass();
    computePass.setPipeline(computePipeline);
    computePass.setBindGroup(0, computeBindGroups[currentBuffer]);
    computePass.dispatchWorkgroups(Math.ceil(NUM_BOIDS / 64));
    computePass.end();

    // Select the output buffer
    const renderBindGroup = renderBindGroups[1 - currentBuffer];

    // Begin render pass
    const renderPass = encoder.beginRenderPass({
        colorAttachments: [{
            view: context.getCurrentTexture().createView(),
            loadOp: "clear",
            clearValue: { r: 0.00, g: 0.00, b: 0.00, a: 1.0 },
            storeOp: "store",
        }]
    });

    // Run render shader 
    renderPass.setPipeline(renderPipeline);
    renderPass.setBindGroup(0, renderBindGroup);
    renderPass.draw(3, NUM_BOIDS);
    renderPass.end();

    // Submit the recorded commands to the GPU for execution
    device.queue.submit([encoder.finish()]);

    // Swap buffers for the next frame
    currentBuffer = 1 - currentBuffer;

    // Loop the render function to create an animation
    requestAnimationFrame(render);
}

// Start the rendering loop
requestAnimationFrame(render);



