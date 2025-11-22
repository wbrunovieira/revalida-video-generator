# Video Generation Server - Terraform Setup

## Status: ⏳ Aguardando aprovação de quota AWS

### O que foi solicitado:
- **Quota:** Running On-Demand G and VT instances
- **Valor:** 96 vCPUs (permite rodar G5.12xlarge)
- **Região:** us-east-2 (Ohio)
- **Status:** Pendente aprovação (24-48 horas)

---

## Quando a quota for aprovada:

### 1. Verificar se foi aprovada
```bash
# No console AWS Service Quotas, ou:
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-DB2E81BA \
  --region us-east-2 \
  --profile bruno-admin-revalida-aws
```

### 2. Criar a infraestrutura
```bash
cd /Users/brunovieira/projects/videos/terraform
terraform apply
```

### 3. Conectar ao servidor
Após o `terraform apply`, você verá as instruções completas no output.

```bash
# SSH
ssh -i ~/.ssh/id_rsa ubuntu@<IP-PUBLICO>

# Copiar vídeos gerados
scp -i ~/.ssh/id_rsa ubuntu@<IP-PUBLICO>:/mnt/output/*.mp4 ~/Downloads/
```

---

## Configuração atual

### Servidor GPU
- **Tipo:** G5.12xlarge (4x NVIDIA A10G, 96GB VRAM)
- **Modo:** Spot Instance (~$1.70/hora, 70% desconto)
- **Sistema:** Ubuntu 22.04 + Deep Learning AMI
- **Região:** us-east-2 (Ohio)

### Storage
- **Root:** 100GB (sistema operacional)
- **Models:** 500GB (modelos de IA)
- **Output:** 200GB (vídeos gerados)

### Software pré-instalado
- CUDA 12+ com drivers NVIDIA
- Python 3.10 + venv
- PyTorch, Diffusers, Transformers
- HuggingFace Hub, xformers
- Jupyter Notebook
- rsync para transferir arquivos

---

## Custos estimados

### Rodando (gerando vídeos)
- **Spot:** ~$1.70/hora
- **On-Demand:** ~$5.67/hora (fallback se Spot não disponível)

### Parado
- **Instância:** $0/hora (Stop quando não usar!)
- **EBS Storage:** ~$56/mês (700GB total)
- **Elastic IP:** $0 (grátis quando associado)

### Economia vs Sora
- **HoloCine:** $0.42/vídeo vs Sora $6-30/vídeo
- **Economia:** 93-98% 🎉

---

## Após criar o servidor

### 1. Montar volumes EBS
```bash
# Primeira vez (formatar)
sudo mkfs -t ext4 /dev/nvme1n1  # Models
sudo mkfs -t ext4 /dev/nvme2n1  # Output

# Montar
sudo mount /dev/nvme1n1 /mnt/models
sudo mount /dev/nvme2n1 /mnt/output

# Auto-mount no boot
echo '/dev/nvme1n1 /mnt/models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
echo '/dev/nvme2n1 /mnt/output ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

### 2. Ativar ambiente Python
```bash
source /home/ubuntu/video-generation/venv/bin/activate
```

### 3. Baixar modelos
```bash
cd /mnt/models

# HunyuanVideo (Recomendado - melhor qualidade)
huggingface-cli download tencent/HunyuanVideo --local-dir HunyuanVideo

# HoloCine (Multi-shot, vídeos longos)
huggingface-cli download yihao-meng/HoloCine --local-dir HoloCine

# CogVideoX-5B (Alternativa menor)
huggingface-cli download THUDM/CogVideoX-5b --local-dir CogVideoX-5b
```

### 4. Verificar GPU
```bash
nvidia-smi
watch -n 1 nvidia-smi  # Monitorar em tempo real
```

---

## Comandos úteis

### Terraform
```bash
# Ver o que será criado
terraform plan

# Criar infraestrutura
terraform apply

# Destruir tudo (CUIDADO!)
terraform destroy

# Ver recursos criados
terraform state list

# Ver outputs (IP, comandos SSH, etc)
terraform output
```

### Gerenciar instância
```bash
# Parar instância (para de cobrar por hora)
aws ec2 stop-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --profile bruno-admin-revalida-aws

# Iniciar instância
aws ec2 start-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --profile bruno-admin-revalida-aws

# Status
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --profile bruno-admin-revalida-aws \
  --query 'Reservations[0].Instances[0].State.Name'
```

---

## Arquitetura

```
┌─────────────────────────────────────────┐
│  EC2 G5.12xlarge (Spot Instance)        │
│  ┌───────────────────────────────────┐  │
│  │ 4x NVIDIA A10G (96GB VRAM)        │  │
│  │ 48 vCPUs, 192GB RAM               │  │
│  │ Ubuntu 22.04 + Deep Learning AMI  │  │
│  └───────────────────────────────────┘  │
│                                          │
│  Volumes:                                │
│  ├─ /         100GB (root)               │
│  ├─ /mnt/models  500GB (AI models)       │
│  └─ /mnt/output  200GB (videos)          │
│                                          │
│  Elastic IP: XXX.XXX.XXX.XXX (fixo)      │
└─────────────────────────────────────────┘
           │
           │ SSH (port 22)
           │ Jupyter (port 8888)
           │ TensorBoard (port 6006)
           │
      ┌────▼────┐
      │   Você  │
      └─────────┘
```

---

## Próximos passos

1. ✅ Solicitar quota AWS (FEITO - aguardando aprovação)
2. ⏳ Aguardar email da AWS (24-48h)
3. ⏳ Rodar `terraform apply`
4. ⏳ Baixar modelos de IA
5. ⏳ Começar a gerar vídeos!

---

## Troubleshooting

### Spot Instance foi interrompida
```bash
# Verificar status
terraform refresh
terraform output

# Re-lançar se necessário
terraform apply
```

### Disco cheio
```bash
# Verificar uso
df -h

# Limpar vídeos antigos
rm /mnt/output/*.mp4

# Aumentar volume (não pode diminuir!)
# Editar terraform.tfvars e terraform apply
```

### GPU não detectada
```bash
# Verificar drivers
nvidia-smi

# Se falhar, reinstalar
sudo apt-get install --reinstall nvidia-driver-550
sudo reboot
```

---

**Criado em:** 22/11/2025
**Autor:** Claude Code
**Projeto:** video-generation
