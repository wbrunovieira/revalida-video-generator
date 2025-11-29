# Plano de Reorganização de Storage

## Situação Atual (BAGUNÇA)

| Volume | Tamanho | Mount | Conteúdo |
|--------|---------|-------|----------|
| nvme1n1 | 500GB EBS | NÃO MONTADO | CogVideoX1.5-5B-I2V (duplicado) |
| nvme2n1 | 200GB EBS | /mnt/output | Vídeos + TODOS modelos (Ovi, Wan, CogVideoX) |
| nvme3n1 | 500GB EBS | /mnt/models2 | CogVideoX1.5-5B-I2V (29GB) |
| nvme4n1 | 3.5TB Instance Store | /opt/dlami/nvme | Efêmero |
| /mnt/models | symlink | → /opt/dlami/nvme/models | VAZIO! |

## Arquitetura Alvo (LIMPA)

| Volume | Mount | Propósito |
|--------|-------|-----------|
| 1x EBS 500GB | /mnt/models | Todos os modelos AI |
| Instance Store 3.5TB | /mnt/output | Vídeos temporários (sincroniza para local) |

**Economia:** ~$40/mês (removendo 1x 500GB + 1x 200GB EBS)

---

## FASE 1: Migrar Dados na Instância Atual (SEM PERDER NADA)

### 1.1 Mover modelos de /mnt/output para /mnt/models2

```bash
# Executar manualmente via SSH
# Mover Ovi
mv /mnt/output/Ovi /mnt/models2/
mv /mnt/output/Ovi-venv /mnt/models2/
mv /mnt/output/Ovi-code /mnt/models2/

# Mover Wan14B
mv /mnt/output/Wan14B-venv /mnt/models2/

# Mover CogVideoX
mv /mnt/output/CogVideoX-5b /mnt/models2/
mv /mnt/output/CogVideoX-venv /mnt/models2/
```

### 1.2 Corrigir symlink /mnt/models

```bash
# Remover symlink atual (aponta para efêmero)
sudo rm -f /mnt/models

# Criar symlink para EBS
sudo ln -sf /mnt/models2 /mnt/models
sudo chown ubuntu:ubuntu /mnt/models
```

### 1.3 Criar /mnt/output no efêmero

```bash
sudo mkdir -p /opt/dlami/nvme/output
sudo ln -sf /opt/dlami/nvme/output /mnt/output
sudo chown ubuntu:ubuntu /mnt/output /opt/dlami/nvme/output
```

### 1.4 Verificar estrutura final

```bash
ls -la /mnt/
# Deve mostrar:
# models -> /mnt/models2
# models2 (500GB EBS montado)
# output -> /opt/dlami/nvme/output

df -h /mnt/models /mnt/output
# models: 500GB EBS
# output: 3.5TB Instance Store
```

---

## FASE 2: Atualizar Código (Ansible/Terraform/Makefile)

### 2.1 Arquivos a modificar:

| Arquivo | Mudança |
|---------|---------|
| `terraform/storage.tf` | Remover `aws_ebs_volume.output`, manter só 1 de 500GB |
| `terraform/variables.tf` | Remover `output_volume_size` |
| `ansible/playbook.yml` | Simplificar mount (só 1 EBS), criar /mnt/output no efêmero |
| `ansible/files/mount-ebs.sh` | Montar 1 EBS em /mnt/models, criar output no efêmero |
| `ansible/tasks/setup-ovi.yml` | Usar sempre `/mnt/models` (sem fallback DLAMI) |
| `ansible/tasks/setup-wan14b.yml` | Usar sempre `/mnt/models` |
| `ansible/tasks/setup-cogvideox.yml` | Usar sempre `/mnt/models` |

### 2.2 terraform/storage.tf (NOVO)

```hcl
# Apenas 1 EBS para modelos
resource "aws_ebs_volume" "models" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.models_volume_size  # 500GB
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true

  tags = {
    Name    = "${var.project_name}-models-volume"
    Project = var.project_name
    Purpose = "AI model storage"
  }
}

# REMOVIDO: aws_ebs_volume.output
```

### 2.3 ansible/files/mount-ebs.sh (NOVO)

```bash
#!/bin/bash
# mount-ebs.sh - Mount EBS volume after server restart

echo "🔍 Detecting EBS volume..."

# Find the 500GB EBS volume (not root, not instance store)
MODELS_VOL=$(lsblk -d -n -o NAME,SIZE | grep -E '500G|400G' | head -1 | awk '{print $1}')

if [ -z "$MODELS_VOL" ]; then
    echo "❌ No EBS volume found"
    lsblk
    exit 1
fi

echo "📦 Found models volume: /dev/$MODELS_VOL"

# Mount to /mnt/models2 (primary mount point)
sudo mkdir -p /mnt/models2
if ! mountpoint -q /mnt/models2; then
    sudo mount /dev/$MODELS_VOL /mnt/models2
    echo "✅ Mounted /dev/$MODELS_VOL -> /mnt/models2"
else
    echo "✅ /mnt/models2 already mounted"
fi

# Create symlink /mnt/models -> /mnt/models2
sudo rm -f /mnt/models 2>/dev/null || true
sudo ln -sf /mnt/models2 /mnt/models

# Create output on ephemeral storage
sudo mkdir -p /opt/dlami/nvme/output
sudo rm -f /mnt/output 2>/dev/null || true
sudo ln -sf /opt/dlami/nvme/output /mnt/output

# Set permissions
sudo chown -R ubuntu:ubuntu /mnt/models2 /opt/dlami/nvme/output 2>/dev/null || true

echo ""
echo "📊 Storage status:"
df -h /mnt/models /mnt/output
echo ""
echo "✅ Storage ready"
```

---

## FASE 3: Remover EBS Extras (DEPOIS de migrar dados)

### 3.1 Desanexar volumes não usados via AWS Console

1. Desmontar nvme1n1: `sudo umount /dev/nvme1n1` (se montado)
2. Desmontar nvme2n1:
   - Primeiro mover vídeos importantes para local
   - `sudo umount /mnt/output`
3. No AWS Console: Detach volumes
4. Deletar volumes não usados

### 3.2 Atualizar Terraform state

```bash
# Remover volume output do state (já deletado manualmente)
cd terraform
terraform state rm aws_ebs_volume.output
terraform state rm aws_volume_attachment.output
```

---

## Ordem de Execução

1. [ ] **Backup**: Sync vídeos importantes para local (`make sync-videos`)
2. [ ] **Migrar dados**: Executar comandos da FASE 1.1 e 1.2 via SSH
3. [ ] **Testar**: Verificar que modelos funcionam no novo local
4. [ ] **Atualizar código**: Aplicar mudanças da FASE 2
5. [ ] **Testar start/stop**: `make stop`, `make start`, verificar mount
6. [ ] **Remover EBS extras**: FASE 3 (só depois de tudo funcionando)

---

## Modelos Atuais (para referência)

| Modelo | Tamanho Aprox | Local Atual | Local Final |
|--------|---------------|-------------|-------------|
| Ovi checkpoints | ~91GB | /mnt/output/Ovi | /mnt/models/Ovi |
| Ovi-venv | ~5GB | /mnt/output/Ovi-venv | /mnt/models/Ovi-venv |
| Ovi-code | ~100MB | /mnt/output/Ovi-code | /mnt/models/Ovi-code |
| Wan 2.2 TI2V | ~30GB | /mnt/output/Ovi/Wan2.2 | /mnt/models/Wan2.2 |
| Wan14B-venv | ~5GB | /mnt/output/Wan14B-venv | /mnt/models/Wan14B-venv |
| CogVideoX-5b | ~10GB | /mnt/output/CogVideoX-5b | /mnt/models/CogVideoX-5b |
| CogVideoX1.5-5B-I2V | ~29GB | /mnt/models2 (já OK) | /mnt/models |
| CogVideoX-venv | ~5GB | /mnt/output/CogVideoX-venv | /mnt/models/CogVideoX-venv |

**Total estimado**: ~175GB (cabe bem em 500GB)
