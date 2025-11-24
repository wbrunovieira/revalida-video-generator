# HunyuanVideo: Guia de Uso

## 📋 O que é

HunyuanVideo é um modelo da Tencent com **melhor qualidade visual** entre os modelos open-source, gerando vídeos em **1280×720 a 30 FPS**.

**Diferencial:** Suporta LoRA training para consistência de personagens entre vídeos diferentes.

## 🎯 Características Principais

- **Melhor qualidade visual**: 720p nativo, 30 FPS
- **Suporte a LoRA**: Treine com imagens de referência para personagens consistentes
- **13B parâmetros**: Modelo grande e poderoso
- **3D Causal VAE**: Melhor compressão temporal
- **Até 5 segundos**: Por geração individual

## 📦 Modelo já está instalado

O Ansible já baixou o modelo em `/mnt/models/HunyuanVideo/`

```
/mnt/models/HunyuanVideo/
├── model_index.json
├── transformer/
├── vae/
├── text_encoder/
└── scheduler/
```

## 🚀 Como Usar

### 1. Conectar ao servidor

```bash
make ssh
```

### 2. Ativar ambiente

```bash
venv
cd /mnt/output  # Vídeos serão salvos aqui
```

### 3. Usar com Diffusers (Hugging Face)

Crie um script Python `generate_hunyuan.py`:

```python
import torch
from diffusers import HunyuanVideoPipeline

# Carregar modelo
pipe = HunyuanVideoPipeline.from_pretrained(
    "/mnt/models/HunyuanVideo",
    torch_dtype=torch.float16,
    device_map="balanced"  # Distribui entre as 4 GPUs
)

# Gerar vídeo
prompt = "Uma borboleta azul voa em um jardim florido, câmera lenta, fotorealista, luz natural"

video = pipe(
    prompt=prompt,
    num_frames=129,  # ~5 segundos a 30 FPS
    height=720,
    width=1280,
    num_inference_steps=50,
    guidance_scale=7.5,
).frames[0]

# Salvar
from diffusers.utils import export_to_video
export_to_video(video, "output.mp4", fps=30)
```

Execute:
```bash
python generate_hunyuan.py
```

## ✍️ Dicas de Prompt

### Estrutura Recomendada

```
[Sujeito] + [Ação] + [Ambiente] + [Estilo] + [Qualidade]
```

### Exemplos

**Natureza:**
```
Um tigre caminha pela floresta tropical, neblina matinal, cinematográfico, 4K, fotorealista
```

**Urbano:**
```
Carro esportivo vermelho atravessa rua molhada à noite, neon lights, câmera lenta, alta qualidade
```

**Fantasia:**
```
Dragão voando sobre montanhas ao pôr do sol, escamas brilhantes, épico, estilo cinema
```

### Palavras-chave que Funcionam Bem

- **Qualidade:** `fotorealista`, `4K`, `alta qualidade`, `cinematográfico`
- **Movimento:** `câmera lenta`, `movimento suave`, `dinâmico`
- **Iluminação:** `luz natural`, `golden hour`, `neon lights`, `contraluz`
- **Estilo:** `estilo cinema`, `professional`, `detailed`

## ⚙️ Parâmetros Importantes

### Número de Frames

```python
num_frames=129    # ~5 segundos (recomendado)
num_frames=65     # ~2.5 segundos (mais rápido)
num_frames=257    # ~10 segundos (requer mais VRAM)
```

### Resolução

```python
# Qualidade máxima (padrão)
height=720, width=1280

# Menor VRAM
height=480, width=854
```

### Inference Steps

```python
num_inference_steps=50   # Boa qualidade (padrão)
num_inference_steps=30   # Mais rápido, qualidade ok
num_inference_steps=100  # Melhor qualidade, mais lento
```

### Guidance Scale

```python
guidance_scale=7.5   # Padrão equilibrado
guidance_scale=5.0   # Mais criativo
guidance_scale=10.0  # Mais fiel ao prompt
```

## 🎨 LoRA Training (Consistência de Personagens)

### Workflow Recomendado

1. **Gerar 30 imagens de referência** do personagem
2. **Treinar LoRA** com essas imagens (usar ferramentas como Kohya SS)
3. **Aplicar LoRA** em todas as gerações de vídeo

### Exemplo com LoRA

```python
from diffusers import HunyuanVideoPipeline

pipe = HunyuanVideoPipeline.from_pretrained(
    "/mnt/models/HunyuanVideo",
    torch_dtype=torch.float16,
    device_map="balanced"
)

# Carregar LoRA treinado
pipe.load_lora_weights("/mnt/models/lora/meu_personagem.safetensors")

# Gerar com personagem consistente
video = pipe(
    prompt="meu_personagem caminhando na praia ao pôr do sol",
    num_frames=129,
    height=720,
    width=1280,
).frames[0]
```

## 📊 Requisitos de VRAM

- **720p, 129 frames:** ~80GB VRAM (ok com 4x A10G)
- **480p, 129 frames:** ~40GB VRAM
- **720p, 65 frames:** ~40GB VRAM

## 📍 Localização dos Vídeos

Vídeos gerados ficam em `/mnt/output/`

Para copiar para sua máquina local:
```bash
scp -i ~/.ssh/id_rsa ubuntu@IP:/mnt/output/*.mp4 ~/Downloads/
```

## 🔧 Troubleshooting

### Erro de memória (CUDA out of memory)

**Solução 1:** Reduzir frames
```python
num_frames=65  # ao invés de 129
```

**Solução 2:** Reduzir resolução
```python
height=480, width=854  # ao invés de 720×1280
```

**Solução 3:** Usar model offloading
```python
pipe.enable_model_cpu_offload()
```

### Vídeo com artefatos

- Aumentar `num_inference_steps` para 70-100
- Ajustar `guidance_scale` (testar 5.0-10.0)
- Melhorar o prompt (ser mais específico)

### Movimento não natural

- Adicionar `smooth motion` ao prompt
- Reduzir número de frames (menos movimento por segundo)
- Usar `slow motion` ou `câmera lenta` no prompt

## 📚 Recursos

- **Hugging Face:** https://huggingface.co/tencent/HunyuanVideo
- **GitHub:** https://github.com/Tencent/HunyuanVideo
- **Paper:** [HunyuanVideo: A Systematic Framework For Large Video Generation Models]

## 💡 Combinação com Outros Modelos

### Upscale com Video Upscaler

```bash
# Gerar em 480p (mais rápido)
python generate_hunyuan.py --height 480 --width 854

# Fazer upscale para 1080p com outro modelo
python upscale_video.py input.mp4 output_1080p.mp4
```

### Multi-shot com Edição

1. Gere múltiplos vídeos com HunyuanVideo
2. Use LoRA para manter personagem consistente
3. Edite no After Effects ou Premiere

## 📄 Licença

Tencent Open Source License

**Verifique termos de uso comercial no repositório oficial.**
