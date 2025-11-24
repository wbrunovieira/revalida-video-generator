# Geração Automatizada de Vídeos HoloCine

## 🚀 Workflow Simplificado

### 1. Editar configuração JSON localmente (fácil!)

```bash
# Copiar template
cp template.json meu_video.json

# Editar no VSCode
code meu_video.json
```

### 2. Copiar arquivos para o servidor

```bash
# Copiar script e configs
scp -i ~/.ssh/id_rsa run_holocine.py ubuntu@18.223.84.101:/mnt/output/
scp -i ~/.ssh/id_rsa video_configs/*.json ubuntu@18.223.84.101:/mnt/output/
```

### 3. Gerar vídeo no servidor

```bash
# SSH no servidor
ssh -i ~/.ssh/id_rsa ubuntu@18.223.84.101

# Ativar ambiente
source /home/ubuntu/video-generation/venv/bin/activate

# Gerar vídeo específico
python /mnt/output/run_holocine.py /mnt/output/meu_video.json

# Ou gerar todos
cd /mnt/output
python run_holocine.py aula01_hospital_recepcao.json
python run_holocine.py aula02_enfermaria.json
```

### 4. Vídeos sincronizam automaticamente

Os vídeos aparecerão em `~/Videos/revalida/` no seu Mac (auto-sync a cada 5 min).

## 📝 Formato do JSON

```json
{
  "output_name": "nome_sem_extensao",
  "global_caption": "Descrição geral em inglês",
  "shot_captions": [
    "Shot 1 description",
    "Shot 2 description",
    "Shot 3 description"
  ],
  "negative_prompt": "what to avoid",
  "num_frames": 81,
  "height": 480,
  "width": 832,
  "steps": 30,
  "fps": 15,
  "seed": 42
}
```

## 💡 Dicas

- **global_caption**: Descreve a cena toda em 1-2 frases
- **shot_captions**: Lista de 3-5 shots (Wide, Medium, Close-up)
- **num_frames**: 81 = ~5s, 161 = ~10s, 241 = ~15s
- **seed**: Mude para obter variações diferentes

## 📚 Exemplos Prontos

- `aula01_hospital_recepcao.json` - Chegada no hospital
- `aula02_enfermaria.json` - Visita na enfermaria
- `template.json` - Template base para copiar
