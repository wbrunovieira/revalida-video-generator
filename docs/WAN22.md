# Wan 2.2: Guia de Uso

## 📋 O que é

Wan 2.2 é um modelo da Wan-AI com arquitetura **MoE (Mixture-of-Experts)**, sendo o mais **versátil** dos modelos, suportando tanto **text-to-video** quanto **image-to-video**.

**Diferencial:** Flexibilidade - aceita texto, imagem, ou ambos como entrada.

## 🎯 Características Principais

- **Dual-mode**: Text-to-Video (T2V) + Image-to-Video (I2V)
- **MoE Architecture**: Eficiente e poderosa
- **14B parâmetros**: Modelo robusto
- **Qualidade profissional**: Boa para produção
- **Até 10 segundos**: Por geração

## 📦 Modelo já está instalado

O Ansible já baixou o modelo em `/mnt/models/Wan2.2/`

```
/mnt/models/Wan2.2/
├── models_t5_umt5-xxl-enc-bf16.pth  # Text encoder
├── Wan2.1_VAE.pth                    # VAE
├── high_noise_model/                 # DiT high noise
└── low_noise_model/                  # DiT low noise
```

## 🚀 Como Usar

### 1. Conectar ao servidor

```bash
make ssh
```

### 2. Ativar ambiente

```bash
venv
cd /mnt/output
```

### 3. Text-to-Video (T2V)

Crie um script Python `generate_wan_t2v.py`:

```python
import torch
from diffusers import WanVideoPipeline

# Carregar modelo T2V
pipe = WanVideoPipeline.from_pretrained(
    "/mnt/models/Wan2.2",
    torch_dtype=torch.float16,
    device_map="balanced"
)

# Gerar vídeo
prompt = "Um astronauta flutua no espaço, terra ao fundo, estrelas cintilantes, cinematográfico"

video = pipe(
    prompt=prompt,
    num_frames=240,  # ~10 segundos
    height=720,
    width=1280,
    num_inference_steps=50,
    guidance_scale=7.0,
).frames[0]

# Salvar
from diffusers.utils import export_to_video
export_to_video(video, "astronauta.mp4", fps=24)
```

### 4. Image-to-Video (I2V)

Crie um script Python `generate_wan_i2v.py`:

```python
import torch
from PIL import Image
from diffusers import WanVideoPipeline

# Carregar modelo I2V
pipe = WanVideoPipeline.from_pretrained(
    "/mnt/models/Wan2.2",
    torch_dtype=torch.float16,
    device_map="balanced"
)

# Carregar imagem inicial
image = Image.open("primeira_frame.jpg")

# Gerar vídeo a partir da imagem
prompt = "A imagem ganha vida, flores balançam com o vento, suave e natural"

video = pipe(
    prompt=prompt,
    image=image,  # Primeira frame fixa
    num_frames=240,
    height=720,
    width=1280,
    num_inference_steps=50,
    guidance_scale=7.0,
).frames[0]

# Salvar
from diffusers.utils import export_to_video
export_to_video(video, "flores_animadas.mp4", fps=24)
```

Execute:
```bash
python generate_wan_t2v.py
# ou
python generate_wan_i2v.py
```

## ✍️ Dicas de Prompt

### Text-to-Video (T2V)

**Estrutura:**
```
[Sujeito] + [Ação] + [Ambiente] + [Movimento de câmera] + [Estilo]
```

**Exemplos:**
```
# Natureza
Cachoeira fluindo em floresta tropical, pássaros voando, câmera lenta, dourado hour

# Urbano
Rua de Tokyo à noite, chuva, luzes neon refletindo, câmera em movimento, cyberpunk

# Abstrato
Tinta colorida se espalhando na água, movimento fluido, macro, artístico
```

### Image-to-Video (I2V)

**Foco no movimento:**
```
# Sutil
Folhas balançam suavemente com a brisa, movimento natural, tranquilo

# Dinâmico
Ondas gigantes quebrando na praia, dramático, poderoso, câmera fixa

# Atmosférico
Névoa se movendo entre as árvores, misterioso, cinematográfico
```

**Dica:** No I2V, descreva o *movimento* que você quer, não a cena completa (ela já está na imagem).

## ⚙️ Parâmetros Importantes

### Número de Frames

```python
num_frames=240    # ~10 segundos a 24 FPS (padrão)
num_frames=120    # ~5 segundos (mais rápido)
num_frames=480    # ~20 segundos (requer muita VRAM)
```

### Resolução

```python
# Qualidade alta
height=720, width=1280

# Balanceado
height=576, width=1024

# Rápido
height=480, width=854
```

### Guidance Scale

```python
guidance_scale=7.0   # Padrão (recomendado)
guidance_scale=5.0   # Mais criativo
guidance_scale=9.0   # Mais fiel ao prompt
```

### Inference Steps

```python
num_inference_steps=50   # Bom equilíbrio (padrão)
num_inference_steps=30   # Mais rápido
num_inference_steps=80   # Melhor qualidade
```

## 🎨 Workflows Avançados

### 1. Pipeline Completo T2V + I2V

```python
# Passo 1: Gere primeira frame com Stable Diffusion
from diffusers import StableDiffusionPipeline

sd_pipe = StableDiffusionPipeline.from_pretrained("stabilityai/sd-xl-base-1.0")
first_frame = sd_pipe("Um castelo medieval ao pôr do sol").images[0]
first_frame.save("castelo.jpg")

# Passo 2: Anime a imagem com Wan I2V
wan_pipe = WanVideoPipeline.from_pretrained("/mnt/models/Wan2.2")
video = wan_pipe(
    prompt="Nuvens se movendo, luz mudando, pássaros voando",
    image=first_frame,
    num_frames=240
).frames[0]
```

### 2. Sequência de Vídeos

```python
# Gere múltiplos clips e concatene
clips = []

for prompt in [
    "Amanhecer nas montanhas",
    "Sol nascendo lentamente",
    "Pássaros começam a voar"
]:
    video = pipe(prompt=prompt, num_frames=120).frames[0]
    clips.append(video)

# Concatenar com FFmpeg ou edição
```

## 📊 Requisitos de VRAM

### Text-to-Video (T2V)
- **720p, 240 frames:** ~60GB VRAM
- **576p, 240 frames:** ~40GB VRAM
- **480p, 240 frames:** ~30GB VRAM

### Image-to-Video (I2V)
- **720p, 240 frames:** ~50GB VRAM (menos que T2V)
- **576p, 240 frames:** ~35GB VRAM

## 📍 Localização dos Vídeos

Vídeos gerados ficam em `/mnt/output/`

Para copiar para sua máquina local:
```bash
scp -i ~/.ssh/id_rsa ubuntu@IP:/mnt/output/*.mp4 ~/Downloads/
```

## 🔧 Troubleshooting

### Erro de memória

**T2V:**
```python
# Reduzir frames
num_frames=120  # ao invés de 240

# Reduzir resolução
height=576, width=1024
```

**I2V:**
```python
# I2V usa menos memória que T2V
# Geralmente é mais estável
```

### Vídeo muito estático (I2V)

- Seja mais específico no prompt sobre o movimento
- Use palavras como: `dinâmico`, `movimento`, `fluindo`
- Aumente `guidance_scale` para 8-9

### Primeira frame diferente da imagem (I2V)

- Reduza `guidance_scale` para 5-6
- Adicione `high fidelity` ao prompt
- Verifique se a imagem está no formato correto (RGB, não RGBA)

## 📚 Recursos

- **Hugging Face:** https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B
- **GitHub:** https://github.com/Wan-AI/Wan
- **Discord:** Comunidade ativa para suporte

## 💡 Quando Usar Wan 2.2

**Use T2V quando:**
- Quer explorar conceitos novos
- Não tem imagem de referência
- Quer variação criativa

**Use I2V quando:**
- Tem uma imagem perfeita já pronta
- Quer controle exato da primeira frame
- Quer animar arte/foto existente
- Precisa de consistência visual precisa

**Vantagens sobre outros modelos:**
- ✅ Dois modos (T2V + I2V)
- ✅ Eficiente (MoE architecture)
- ✅ Versátil para diferentes workflows

## 📄 Licença

Wan AI Open Source License

**Verifique termos de uso comercial no repositório oficial.**
