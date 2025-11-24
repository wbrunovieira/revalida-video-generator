import sys
import os
sys.path.insert(0, '/mnt/models/HoloCine/code')
os.chdir('/mnt/models/HoloCine/code')

import torch
from diffsynth import save_video
from diffsynth.pipelines.wan_video_holocine import WanVideoHoloCinePipeline, ModelConfig

print("🏥 Iniciando geração: Primeiro dia no hospital italiano")
print("=" * 60)

# Carregar pipeline com ModelConfig correto
print("📦 Carregando modelo HoloCine...")
device = 'cuda'
pipe = WanVideoHoloCinePipeline.from_pretrained(
    torch_dtype=torch.bfloat16,
    device=device,
    model_configs=[
        ModelConfig(path="/mnt/models/HoloCine/checkpoints/Wan2.2-T2V-A14B/models_t5_umt5-xxl-enc-bf16.pth", offload_device="cpu"),
        ModelConfig(path="/mnt/models/HoloCine/checkpoints/HoloCine_dit/full/full_high_noise.safetensors", offload_device="cpu"),
        ModelConfig(path="/mnt/models/HoloCine/checkpoints/HoloCine_dit/full/full_low_noise.safetensors", offload_device="cpu"),
        ModelConfig(path="/mnt/models/HoloCine/checkpoints/Wan2.2-T2V-A14B/Wan2.1_VAE.pth", offload_device="cpu"),
    ],
)
pipe.enable_vram_management()
pipe.to(device)

print("✅ Modelo carregado!")
print()

# Prompt negativo (em chinês, do exemplo)
negative_prompt = "色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量"

# Prompts do vídeo médico
global_caption = "A professional Italian doctor in white medical coat walking through a modern hospital corridor with natural lighting and medical equipment visible"

shot_captions = [
    "Medium shot of Italian doctor entering hospital corridor, professional appearance, confident walk",
    "Close-up of doctor's face showing friendly expression, hospital environment in background",
    "Wide shot following doctor walking past medical equipment and windows with natural light"
]

print("🎬 Configuração:")
print(f"   Shots: {len(shot_captions)}")
print(f"   Frames: 81 (~5 segundos a 15 FPS)")
print()

# Importar função de inferência
from HoloCine_inference_full_attention import run_inference

# Gerar vídeo
print("🎥 Gerando vídeo... (5-10 min)")
output_path = "/mnt/output/hospital_italiano_holocine.mp4"

run_inference(
    pipe=pipe,
    negative_prompt=negative_prompt,
    output_path=output_path,
    global_caption=global_caption,
    shot_captions=shot_captions,
    num_frames=81,
    height=480,
    width=832,
    num_inference_steps=30,
    fps=15,
    quality=5,
    seed=42,
    tiled=True
)

print()
print("=" * 60)
print(f"✅ Vídeo salvo em: {output_path}")
print("=" * 60)
