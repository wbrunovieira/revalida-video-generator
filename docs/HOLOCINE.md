# HoloCine: Guia de Uso

## 📋 O que é

HoloCine é um modelo text-to-video que gera **cenas completas com múltiplos shots**, mantendo consistência de personagens, objetos e estilo entre todos os planos.

**Diferencial:** Você controla cada shot individualmente através de prompts específicos.

## 🎯 Características Principais

- **Multi-shot nativo**: Gera vários planos em uma única execução
- **Consistência de personagens**: Mesmos personagens em todos os shots
- **Controle de direção**: Define exatamente o que acontece em cada plano
- **Até 60 segundos**: Vídeos longos com narrativa coerente
- **Resolução**: 720×480, 16 FPS

## 📦 Modelo já está instalado

O Ansible já baixou os checkpoints necessários em `/mnt/models/HoloCine/`:

```
/mnt/models/HoloCine/
├── checkpoints/
│   ├── Wan2.2-T2V-A14B/        # VAE e T5 encoder
│   └── HoloCine_dit/
│       ├── full/                # Modelo full attention (recomendado)
│       └── sparse/              # Modelo sparse attention (mais rápido)
└── code/                        # Repositório clonado
```

## 🚀 Como Usar

### 1. Conectar ao servidor

```bash
make ssh
```

### 2. Ativar ambiente e navegar

```bash
venv                                    # Ativa Python environment
cd /mnt/models/HoloCine/code           # Entra no diretório do código
```

### 3. Executar inferência

**Versão Full Attention (recomendada - melhor qualidade):**
```bash
python HoloCine_inference_full_attention.py
```

**Versão Sparse Attention (mais rápida):**
```bash
python HoloCine_inference_sparse_attention.py
```

## ✍️ Formato de Prompt

O HoloCine usa um formato específico para controlar cada shot:

### Opção 1: Input Estruturado (Recomendado)

Edite o arquivo `HoloCine_inference_full_attention.py` e use a função `run_inference()`:

```python
run_inference(
    pipe=pipe,
    negative_prompt=scene_negative_prompt,
    output_path="meu_video.mp4",

    # Descrição global da cena
    global_caption="A cena se passa em um salão Art Deco dos anos 1920 durante um baile de máscaras. [character1] é uma mulher misteriosa com vestido prateado. [character2] é um cavalheiro de smoking. Esta cena contém 5 shots.",

    # Descrição de cada shot
    shot_captions=[
        "Plano médio de [character1] observando a multidão.",
        "Close de [character2] olhando para ela do outro lado do salão.",
        "Plano médio de [character2] se aproximando de [character1].",
        "Close nos olhos de [character1] através da máscara.",
        "Plano médio dos dois conversando, festa desfocada ao fundo."
    ],

    num_frames=241  # 15 segundos (241 frames)
)
```

### Opção 2: String Raw

Se preferir fornecer o prompt completo:

```python
run_inference(
    pipe=pipe,
    negative_prompt=scene_negative_prompt,
    output_path="meu_video.mp4",

    prompt="[global caption] A cena mostra uma jovem pintora, [character1]... Esta cena contém 6 shots. [per shot caption] Plano médio de [character1] observando a tela... [shot cut] Close da mão dela com o pincel... [shot cut] ...",

    num_frames=241,
    shot_cut_frames=[37, 73, 113, 169, 205]  # Frames onde ocorrem os cortes
)
```

## ⚙️ Parâmetros Importantes

### Número de Frames

```python
num_frames=241   # 15 segundos (padrão, recomendado)
num_frames=81    # 5 segundos (se tiver pouca VRAM)
```

### Shot Cuts (cortes de plano)

- **Automático:** O script calcula cortes uniformes baseado no número de shots
- **Manual:** Use `shot_cut_frames=[37, 73, 113, ...]` para controlar exatamente onde ocorrem

**Importante:** O número de elementos em `shot_cut_frames` deve corresponder ao número de `shot_captions`.

## 📝 Dicas de Prompt

### 1. Use Tags de Personagem

```python
[character1], [character2], [character3]
```

Isso ajuda o modelo a manter consistência.

### 2. Descrição Global Clara

Descreva:
- **Ambiente** (época, local, atmosfera)
- **Personagens** (aparência, roupas)
- **Número de shots** na cena

### 3. Descrições de Shot Específicas

Cada shot deve ter:
- **Tipo de plano** (close, plano médio, plano aberto)
- **Ação** ou **foco** do plano
- **Continuidade** com shots anteriores

### 4. Use LLM para Gerar Prompts

Você pode usar Gemini 2.5 Pro ou ChatGPT para gerar prompts no formato correto:

```
Prompt para LLM: "Crie um prompt multi-shot no formato HoloCine para uma cena de [tema]. Use [X] shots e mantenha consistência entre eles."
```

## 🎬 Exemplos Prontos

O script já vem com vários exemplos comentados. Descomente-os para testar:

```bash
# No arquivo HoloCine_inference_full_attention.py
# Procure por linhas comentadas com exemplos (#)
# Descomente e execute
```

## 📊 Requisitos de VRAM

- **241 frames (15s):** ~96GB VRAM (4x A10G ok)
- **81 frames (5s):** ~40GB VRAM (2x A10G ok)

Se der erro de memória, reduza `num_frames` para 81.

## 📍 Localização dos Vídeos

Vídeos gerados ficam em:
- `/mnt/models/HoloCine/code/` (por padrão)
- Ou no caminho especificado em `output_path`

Para copiar para sua máquina local:
```bash
scp -i ~/.ssh/id_rsa ubuntu@IP:/mnt/models/HoloCine/code/*.mp4 ~/Downloads/
```

## 🔧 Troubleshooting

### Erro de memória (CUDA out of memory)

Reduza o número de frames:
```python
num_frames=81  # ao invés de 241
```

### Personagens inconsistentes

- Use tags `[character1]`, `[character2]` consistentemente
- Seja específico nas descrições (cor de roupa, características físicas)
- Mantenha o `global_caption` detalhado

### Texto truncado

O encoder T5 limita prompts a 512 tokens. Se o prompt for muito longo:
- Seja mais conciso
- Remova descrições redundantes
- Foque no essencial de cada shot

## 📚 Recursos

- **GitHub:** https://github.com/yihao-meng/HoloCine
- **Paper:** [HoloCine: Holistic Generation of Cinematic Multi-Shot Long Video Narratives]
- **Página do Projeto:** Veja a demo page para exemplos de vídeos

## 📄 Licença

CC BY-NC-SA 4.0 (Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License)

**Uso apenas para pesquisa acadêmica.**
