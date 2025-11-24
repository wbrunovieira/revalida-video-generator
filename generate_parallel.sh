#!/bin/bash
# Script para gerar múltiplos vídeos em paralelo usando todas as GPUs disponíveis
# Uso: ./generate_parallel.sh config1.json config2.json config3.json config4.json

# Ativar ambiente virtual
source /home/ubuntu/video-generation/venv/bin/activate

# Diretório dos scripts
SCRIPT_DIR="/mnt/output"

# Array de configurações passadas como argumentos
CONFIGS=("$@")

# Número de GPUs disponíveis
NUM_GPUS=4

# Verificar se há configurações suficientes
if [ ${#CONFIGS[@]} -eq 0 ]; then
    echo "Uso: $0 <config1.json> [config2.json] [config3.json] [config4.json]"
    echo "Exemplo: $0 /mnt/output/aula01.json /mnt/output/aula02.json"
    exit 1
fi

echo "🚀 Gerando ${#CONFIGS[@]} vídeo(s) em paralelo usando $NUM_GPUS GPUs"

# Array para armazenar PIDs dos processos
PIDS=()

# Gerar vídeos em paralelo
for i in "${!CONFIGS[@]}"; do
    CONFIG="${CONFIGS[$i]}"
    GPU_ID=$((i % NUM_GPUS))

    echo "📹 GPU $GPU_ID: Gerando $(basename $CONFIG)"

    # Rodar em background, cada processo em uma GPU diferente
    CUDA_VISIBLE_DEVICES=$GPU_ID python3 $SCRIPT_DIR/run_holocine.py "$CONFIG" > "${CONFIG%.json}.log" 2>&1 &

    PIDS+=($!)

    # Pequeno delay para evitar race conditions
    sleep 2
done

echo ""
echo "⏳ Aguardando conclusão de todos os vídeos..."
echo "   PIDs: ${PIDS[@]}"
echo ""

# Aguardar todos os processos terminarem
for i in "${!PIDS[@]}"; do
    PID=${PIDS[$i]}
    CONFIG="${CONFIGS[$i]}"

    wait $PID
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ Concluído: $(basename $CONFIG)"
    else
        echo "❌ Erro em: $(basename $CONFIG) (código: $EXIT_CODE)"
        echo "   Ver log: ${CONFIG%.json}.log"
    fi
done

echo ""
echo "🎉 Todos os vídeos foram processados!"
echo "📁 Vídeos salvos em: /mnt/output/"
