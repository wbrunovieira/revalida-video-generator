import sys
import os
import json
import importlib.util

# Configure CUDA memory management BEFORE importing torch
os.environ['PYTORCH_ALLOC_CONF'] = 'expandable_segments:True'
os.environ['CUDA_VISIBLE_DEVICES'] = '0,1,2,3'

sys.path.insert(0, '/mnt/models/HoloCine/code')
os.chdir('/mnt/models/HoloCine/code')

import torch
from diffsynth.pipelines.wan_video_holocine import WanVideoHoloCinePipeline, ModelConfig

# Carregar configuração
config_file = sys.argv[1] if len(sys.argv) > 1 else "/mnt/output/video_config.json"

with open(config_file, 'r', encoding='utf-8') as f:
    config = json.load(f)

print(f"🎬 Gerando: {config['output_name']}")

# Carregar modelo com offloading para CPU
# Nota: HoloCine usa VRAM management interno, não suporta multi-GPU nativamente
device = 'cuda'
pipe = WanVideoHoloCinePipeline.from_pretrained(
    torch_dtype=torch.bfloat16,
    device=device,
    model_configs=[
        ModelConfig(path="./checkpoints/Wan2.2-T2V-A14B/Wan2.2-T2V-A14B/models_t5_umt5-xxl-enc-bf16.pth", offload_device="cpu"),
        ModelConfig(path="./checkpoints/HoloCine_dit/sparse/sparse_high_noise.safetensors", offload_device="cpu"),
        ModelConfig(path="./checkpoints/HoloCine_dit/sparse/sparse_low_noise.safetensors", offload_device="cpu"),
        ModelConfig(path="./checkpoints/Wan2.2-T2V-A14B/Wan2.2-T2V-A14B/Wan2.1_VAE.pth", offload_device="cpu"),
    ],
)
pipe.enable_vram_management()

print("📊 Gerando vídeo...")

# Importar run_inference agora, depois que já configuramos tudo
# Isso evita que o código no nível do módulo seja executado antes
from HoloCine_inference_full_attention import run_inference

# Gerar vídeo usando a função original do HoloCine
run_inference(
    pipe=pipe,
    output_path=f"/mnt/output/{config['output_name']}.mp4",
    global_caption=config['global_caption'],
    shot_captions=config['shot_captions'],
    negative_prompt=config.get('negative_prompt', ''),
    num_frames=config.get('num_frames', 81),
    height=config.get('height', 480),
    width=config.get('width', 832),
    num_inference_steps=config.get('steps', 30),
    fps=config.get('fps', 15),
    quality=5,
    seed=config.get('seed', 42),
    tiled=True
)

print(f"✅ Vídeo salvo: /mnt/output/{config['output_name']}.mp4")
