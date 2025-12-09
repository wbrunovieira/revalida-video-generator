#!/bin/bash
# =============================================================================
# Video Generation Script - Automated Model Management
# =============================================================================
# Este script gerencia automaticamente:
# - Seleção de modelo (Ovi, CogVideoX, Wan)
# - Setup do venv isolado se necessário
# - Suporte Multi-GPU (sequence parallel)
# - Modo interativo com prompts separados
# - Execução da geração com logs completos
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Diretórios base
MODELS_DIR="/mnt/models"
OUTPUT_DIR="/mnt/output"
LOG_DIR="/mnt/output/logs"

# Detectar número de GPUs disponíveis
NUM_GPUS=$(nvidia-smi -L 2>/dev/null | wc -l || echo "1")

# Configurações dos modelos
declare -A MODEL_VENV=(
    ["ovi"]="Ovi-venv"
    ["cogvideox"]="CogVideoX-venv"
    ["wan"]="Wan-venv"
    ["wan14b"]="Wan14B-venv"
    ["hunyuan"]="Hunyuan-venv"
)

declare -A MODEL_TORCH=(
    ["ovi"]="torch==2.6.0 torchvision torchaudio"
    ["cogvideox"]="torch torchvision torchaudio"
    ["wan"]="torch torchvision torchaudio"
    ["wan14b"]="torch torchvision torchaudio"
    ["hunyuan"]="torch==2.5.1 torchvision torchaudio"
)

declare -A MODEL_CODE_DIR=(
    ["ovi"]="Ovi-code"
    ["cogvideox"]="CogVideoX-5b"
    ["wan"]="Wan2.2"
    ["wan14b"]="ComfyUI"
    ["hunyuan"]="HunyuanVideo-1.5"
)

# Ovi model variants
OVI_MODEL_VARIANT="${OVI_MODEL:-720x720_5s}"

# =============================================================================
# Funções auxiliares
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}==>${NC} $1"
}

# =============================================================================
# GPU Cleanup - Kill lingering processes to free VRAM
# =============================================================================

cleanup_gpu_processes() {
    log_step "Verificando processos GPU em execução..."

    # Get PIDs of processes using GPU memory
    local gpu_pids=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' || true)

    if [ -n "$gpu_pids" ]; then
        log_info "Processos GPU detectados:"
        nvidia-smi --query-compute-apps=pid,used_memory,name --format=csv,noheader 2>/dev/null | while read line; do
            echo "   $line"
        done

        # Kill each process using GPU
        for pid in $gpu_pids; do
            if [ -n "$pid" ] && [ "$pid" != "pid" ]; then
                local proc_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                log_warn "Matando processo GPU: PID $pid ($proc_name)"
                kill $pid 2>/dev/null || true
            fi
        done

        sleep 3

        # Force kill if still running
        for pid in $gpu_pids; do
            if [ -n "$pid" ] && [ "$pid" != "pid" ] && kill -0 $pid 2>/dev/null; then
                log_warn "Forçando kill -9 no PID $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done

        sleep 2

        # Verify cleanup
        local remaining=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' || true)
        if [ -z "$remaining" ]; then
            log_success "Todos processos GPU encerrados - VRAM livre!"
        else
            log_warn "Alguns processos ainda rodando. Verifique manualmente."
        fi
    else
        log_success "Nenhum processo GPU ativo - VRAM livre!"
    fi
    echo ""
}

show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║          🎬 Video Generation - Revalida Italia 🎬             ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║  Modelos disponíveis:                                         ║"
    echo "║    • ovi       - Video + Audio sincronizado (T2V/I2V)        ║"
    echo "║    • cogvideox - Alta qualidade, multi-GPU (T2V/I2V)         ║"
    echo "║    • wan14b    - Ultra-rápido 4 steps! (I2V)                 ║"
    echo "║    • hunyuan   - HunyuanVideo 8.3B, multi-GPU (T2V/I2V) [NOVO]║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║  GPUs detectadas: ${NUM_GPUS}                                           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_usage() {
    echo "Uso: $0 [opções]"
    echo ""
    echo "Modos:"
    echo "  $0                              Modo interativo (recomendado)"
    echo "  $0 <modelo> <modo> <prompt>     Modo direto"
    echo ""
    echo "Opções:"
    echo "  --interactive, -i      Forçar modo interativo"
    echo "  --multi-gpu            Usar todas as ${NUM_GPUS} GPUs"
    echo "  --model-variant=VAR    Variante Ovi (720x720_5s, 960x960_5s, 960x960_10s)"
    echo ""
    echo "Exemplos:"
    echo "  $0                     # Modo interativo"
    echo "  $0 -i                  # Modo interativo"
    echo "  $0 ovi t2v \"prompt\"   # Modo direto"
    echo ""
}

# =============================================================================
# Modo Interativo - Perguntas separadas
# =============================================================================

interactive_mode() {
    show_banner

    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}                    MODO INTERATIVO                            ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # 1. Escolher modelo
    echo -e "${YELLOW}1. Escolha o modelo:${NC}"
    echo "   1) ovi       - Video + Audio sincronizado"
    echo "   2) cogvideox - Alta qualidade"
    echo "   3) wan14b    - Ultra-rápido (4 steps, I2V apenas)"
    echo "   4) hunyuan   - HunyuanVideo 8.3B multi-GPU (T2V/I2V) [NOVO]"
    echo ""
    read -p "   Modelo [1-4, default=1]: " model_choice
    case "$model_choice" in
        2) MODEL="cogvideox" ;;
        3) MODEL="wan14b" ;;
        4) MODEL="hunyuan" ;;
        *) MODEL="ovi" ;;
    esac
    echo -e "   ${GREEN}✓ Modelo: ${MODEL}${NC}"
    echo ""

    # 2. Escolher modo (T2V ou I2V)
    # wan14b só suporta I2V por enquanto (T2V precisa de custom nodes não instalados)
    if [ "$MODEL" == "wan14b" ]; then
        MODE="i2v"
        echo -e "${YELLOW}2. Modo de geração:${NC}"
        echo -e "   ${CYAN}WAN14B atualmente suporta apenas I2V (Image to Video)${NC}"
        echo -e "   ${GREEN}✓ Modo: i2v (automático)${NC}"
        echo ""
    else
        echo -e "${YELLOW}2. Escolha o modo:${NC}"
        echo "   1) t2v - Text to Video (gerar do zero)"
        echo "   2) i2v - Image to Video (animar imagem)"
        echo ""
        read -p "   Modo [1-2, default=1]: " mode_choice
        case "$mode_choice" in
            2) MODE="i2v" ;;
            *) MODE="t2v" ;;
        esac
        echo -e "   ${GREEN}✓ Modo: ${MODE}${NC}"
        echo ""
    fi

    # 3. Se I2V, pedir imagem
    IMAGE=""
    if [ "$MODE" == "i2v" ]; then
        echo -e "${YELLOW}3. Caminho da imagem:${NC}"
        echo "   (Ex: /mnt/output/doctor.png)"
        echo ""
        read -p "   Imagem: " IMAGE
        if [ ! -f "$IMAGE" ]; then
            log_error "Imagem não encontrada: $IMAGE"
            exit 1
        fi
        echo -e "   ${GREEN}✓ Imagem: ${IMAGE}${NC}"
        echo ""
    fi

    # 4. Escolher variante (apenas para Ovi)
    MODEL_VARIANT="720x720_5s"
    USE_MULTI_GPU="false"

    if [ "$MODEL" == "ovi" ]; then
        # Detectar VRAM da GPU
        local gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')

        if [ -n "$gpu_vram" ] && [ "$gpu_vram" -ge 80000 ]; then
            # GPUs com 80GB+ podem usar outras variantes e multi-GPU
            echo -e "${YELLOW}4. Escolha a qualidade/duração:${NC}"
            echo "   1) 720x720  5s  - Padrão"
            echo "   2) 960x960  5s  - Melhor qualidade"
            echo "   3) 960x960 10s  - Vídeo mais longo"
            echo ""
            read -p "   Qualidade [1-3, default=1]: " variant_choice
            case "$variant_choice" in
                2) MODEL_VARIANT="960x960_5s" ;;
                3) MODEL_VARIANT="960x960_10s" ;;
                *) MODEL_VARIANT="720x720_5s" ;;
            esac
            echo -e "   ${GREEN}✓ Qualidade: ${MODEL_VARIANT}${NC}"
            echo ""

            # Multi-GPU disponível para GPUs grandes
            if [ "$NUM_GPUS" -gt 1 ]; then
                echo -e "${YELLOW}5. Usar Multi-GPU? (${NUM_GPUS} GPUs disponíveis)${NC}"
                echo "   1) Não - Single GPU"
                echo "   2) Sim - Multi-GPU (mais rápido)"
                echo ""
                read -p "   Multi-GPU [1-2, default=1]: " gpu_choice
                case "$gpu_choice" in
                    2) USE_MULTI_GPU="true" ;;
                    *) USE_MULTI_GPU="false" ;;
                esac
                echo -e "   ${GREEN}✓ Multi-GPU: ${USE_MULTI_GPU}${NC}"
                echo ""
            fi
        else
            # GPUs com 24GB (A10G) - apenas 720x720_5s com FP8
            MODEL_VARIANT="720x720_5s"
            USE_MULTI_GPU="false"
            echo -e "${YELLOW}4. Configuração de GPU:${NC}"
            echo -e "   ${CYAN}GPU detectada: ${gpu_vram:-24000}MB VRAM${NC}"
            echo -e "   ${GREEN}✓ Usando: 720x720 5s (único compatível com FP8/24GB)${NC}"
            echo -e "   ${GREEN}✓ Single-GPU com FP8 + CPU Offload${NC}"
            echo ""
        fi
    elif [ "$MODEL" == "wan14b" ]; then
        # Wan14B é ultra-rápido - não precisa de configurações extras
        MODEL_VARIANT="mega-v12"
        USE_MULTI_GPU="false"
        echo -e "${YELLOW}4. Configuração WAN 14B Rapid:${NC}"
        echo -e "   ${GREEN}✓ Modo: Ultra-rápido (4 steps)${NC}"
        echo -e "   ${GREEN}✓ Precisão: FP8${NC}"
        echo -e "   ${GREEN}✓ CFG: 1.0, Sampler: euler_a/beta${NC}"
        echo -e "   ${CYAN}Funciona em GPUs com 8GB+ VRAM${NC}"
        echo ""
    elif [ "$MODEL" == "hunyuan" ]; then
        # HunyuanVideo - resolução (720p default)
        MODEL_VARIANT="720p"
        USE_MULTI_GPU="false"

        # Detect GPU VRAM
        local gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
        local total_vram=$((gpu_vram * NUM_GPUS))

        echo -e "${YELLOW}4. Configuração HunyuanVideo-1.5:${NC}"
        echo "   Resolução:"
        echo "   1) 480p - Mais rápido, menos VRAM"
        echo "   2) 720p - Melhor qualidade (recomendado)"
        echo ""
        read -p "   Resolução [1-2, default=2]: " res_choice
        case "$res_choice" in
            1) MODEL_VARIANT="480p" ;;
            *) MODEL_VARIANT="720p" ;;
        esac
        echo -e "   ${GREEN}✓ Resolução: ${MODEL_VARIANT}${NC}"
        echo ""

        # Multi-GPU Strategy Selection
        if [ "$NUM_GPUS" -gt 1 ]; then
            if [ -n "$gpu_vram" ] && [ "$gpu_vram" -ge 70000 ]; then
                # Large GPUs (A100/H100 80GB+) - use xDiT torchrun
                echo "   Multi-GPU:"
                echo "   1) Não - Single GPU com offloading"
                echo "   2) Sim - xDiT Multi-GPU via torchrun (mais rápido)"
                echo ""
                read -p "   Multi-GPU [1-2, default=2]: " gpu_choice
                case "$gpu_choice" in
                    1) USE_MULTI_GPU="false" ;;
                    *) USE_MULTI_GPU="true" ;;
                esac
            elif [ "$total_vram" -ge 80000 ]; then
                # Multiple smaller GPUs with enough total VRAM (4x A10G = 96GB)
                # Use device_map to split model across GPUs
                echo -e "   ${CYAN}GPU: ${gpu_vram:-24000}MB x ${NUM_GPUS} = ${total_vram}MB total${NC}"
                echo -e "   ${GREEN}✓ Device Map disponível (modelo distribuído entre GPUs)${NC}"
                echo -e "   ${GREEN}   ~10-15 min em vez de ~3.5h com offloading!${NC}"
                echo ""
                echo "   Multi-GPU (device_map):"
                echo "   1) Não - Single GPU com offloading (LENTO: ~4min/step)"
                echo "   2) Sim - Device Map entre ${NUM_GPUS} GPUs (RÁPIDO)"
                echo ""
                read -p "   Multi-GPU [1-2, default=2]: " gpu_choice
                case "$gpu_choice" in
                    1) USE_MULTI_GPU="false" ;;
                    *) USE_MULTI_GPU="true" ;;
                esac
            else
                # Not enough total VRAM
                USE_MULTI_GPU="false"
                echo -e "   ${CYAN}GPU: ${gpu_vram:-24000}MB x ${NUM_GPUS} = ${total_vram}MB${NC}"
                echo -e "   ${YELLOW}⚠️  VRAM total insuficiente para multi-GPU${NC}"
                echo -e "   ${GREEN}✓ Usando Single-GPU com CPU offloading${NC}"
            fi
            echo ""
        fi
    elif [ "$MODEL" == "cogvideox" ]; then
        # CogVideoX - perguntar sobre multi-GPU (único que usa device_map)
        MODEL_VARIANT="5b"
        USE_MULTI_GPU="false"
        if [ "$NUM_GPUS" -gt 1 ]; then
            echo -e "${YELLOW}4. Usar Multi-GPU? (${NUM_GPUS} GPUs disponíveis)${NC}"
            echo "   1) Não - Single GPU com CPU offload (~5GB VRAM)"
            echo "   2) Sim - Multi-GPU via device_map (~15GB/GPU, mais rápido)"
            echo ""
            read -p "   Multi-GPU [1-2, default=1]: " gpu_choice
            case "$gpu_choice" in
                2) USE_MULTI_GPU="true" ;;
                *) USE_MULTI_GPU="false" ;;
            esac
            echo -e "   ${GREEN}✓ Multi-GPU: ${USE_MULTI_GPU}${NC}"
            echo ""
        else
            echo -e "${YELLOW}4. Configuração CogVideoX:${NC}"
            echo -e "   ${GREEN}✓ Single GPU com CPU offload (~5GB VRAM)${NC}"
            echo ""
        fi
    else
        # Wan 2.2 - single GPU padrão
        MODEL_VARIANT="2.2"
        USE_MULTI_GPU="false"
        echo -e "${YELLOW}4. Configuração Wan 2.2:${NC}"
        echo -e "   ${GREEN}✓ Single GPU com CPU offload${NC}"
        echo ""
    fi

    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}                    CONFIGURAÇÃO DO PROMPT                     ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # 6. Descrição visual da cena
    echo -e "${YELLOW}6. Descreva a CENA (visual):${NC}"
    echo "   O que aparece no vídeo? Descreva a pessoa, ambiente, iluminação..."
    echo ""
    echo -e "   ${CYAN}Exemplo: Italian doctor in white coat, warm smile, professional${NC}"
    echo -e "   ${CYAN}         office background, soft lighting${NC}"
    echo ""
    read -p "   Cena: " SCENE_DESC
    echo ""

    # 7. Fala (opcional)
    echo -e "${YELLOW}7. O que a pessoa VAI FALAR? (opcional):${NC}"
    echo "   Deixe em branco se não houver fala"
    echo ""
    echo -e "   ${CYAN}Exemplo: Buongiorno, benvenuti al corso di italiano medico${NC}"
    echo ""
    read -p "   Fala: " SPEECH_TEXT
    echo ""

    # 8. Descrição do áudio/música de fundo
    echo -e "${YELLOW}8. Descreva o ÁUDIO de fundo (opcional):${NC}"
    echo "   Música, sons ambiente, etc."
    echo ""
    echo -e "   ${CYAN}Exemplo: Soft piano music, hospital ambiance${NC}"
    echo ""
    read -p "   Áudio: " AUDIO_DESC
    echo ""

    # Montar prompt final
    FINAL_PROMPT=$(build_ovi_prompt "$SCENE_DESC" "$SPEECH_TEXT" "$AUDIO_DESC" "$MODEL_VARIANT")

    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}                    RESUMO DA GERAÇÃO                          ${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Modelo:${NC}      $MODEL"
    echo -e "${GREEN}Modo:${NC}        $MODE"
    [ -n "$IMAGE" ] && echo -e "${GREEN}Imagem:${NC}      $IMAGE"
    echo -e "${GREEN}Qualidade:${NC}   $MODEL_VARIANT"
    echo -e "${GREEN}Multi-GPU:${NC}   $USE_MULTI_GPU"
    echo ""
    echo -e "${GREEN}Prompt final:${NC}"
    echo -e "${CYAN}$FINAL_PROMPT${NC}"
    echo ""

    read -p "Confirmar e gerar? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        echo "Cancelado."
        exit 0
    fi

    # Exportar variáveis para uso no resto do script
    export INTERACTIVE_MODEL="$MODEL"
    export INTERACTIVE_MODE="$MODE"
    export INTERACTIVE_PROMPT="$FINAL_PROMPT"
    export INTERACTIVE_IMAGE="$IMAGE"
    export INTERACTIVE_VARIANT="$MODEL_VARIANT"
    export INTERACTIVE_MULTI_GPU="$USE_MULTI_GPU"
}

# =============================================================================
# Construir prompt Ovi formatado
# =============================================================================

build_ovi_prompt() {
    local scene="$1"
    local speech="$2"
    local audio="$3"
    local variant="$4"

    local prompt="$scene"
    local audio_part=""

    # Construir parte do áudio
    if [ -n "$speech" ] && [ -n "$audio" ]; then
        audio_part="<S>${speech}<E> ${audio}"
    elif [ -n "$speech" ]; then
        audio_part="<S>${speech}<E>"
    elif [ -n "$audio" ]; then
        audio_part="${audio}"
    fi

    # Formatar baseado na variante
    if [ -n "$audio_part" ]; then
        case "$variant" in
            "720x720_5s")
                # Modelo 720p usa <AUDCAP>...<ENDAUDCAP>
                prompt="${prompt} <AUDCAP>${audio_part}<ENDAUDCAP>"
                ;;
            *)
                # Modelos 960p usam Audio: ...
                prompt="${prompt} Audio: ${audio_part}"
                ;;
        esac
    fi

    echo "$prompt"
}

# =============================================================================
# Setup do ambiente virtual
# =============================================================================

check_venv_exists() {
    local model=$1
    local venv_path="${MODELS_DIR}/${MODEL_VENV[$model]}"

    if [ -d "$venv_path" ] && [ -f "$venv_path/bin/activate" ]; then
        return 0
    else
        return 1
    fi
}

check_venv_valid() {
    local model=$1
    local venv_path="${MODELS_DIR}/${MODEL_VENV[$model]}"

    source "$venv_path/bin/activate"

    if python -c "import torch; print(torch.__version__)" &>/dev/null; then
        deactivate 2>/dev/null || true
        return 0
    else
        deactivate 2>/dev/null || true
        return 1
    fi
}

setup_venv() {
    local model=$1
    local venv_path="${MODELS_DIR}/${MODEL_VENV[$model]}"
    local code_dir="${MODELS_DIR}/${MODEL_CODE_DIR[$model]}"

    log_step "Configurando ambiente virtual para ${model}..."

    if [ ! -d "$venv_path" ]; then
        log_info "Criando venv em $venv_path"
        python3 -m venv "$venv_path"
    fi

    source "$venv_path/bin/activate"

    log_info "Atualizando pip..."
    pip install --upgrade pip --quiet

    log_info "Instalando PyTorch (${MODEL_TORCH[$model]})..."
    pip install ${MODEL_TORCH[$model]} --index-url https://download.pytorch.org/whl/cu121 --quiet

    if [ -f "$code_dir/requirements.txt" ]; then
        log_info "Instalando dependências de $code_dir/requirements.txt..."
        pip install -r "$code_dir/requirements.txt" --quiet
    fi

    if [ "$model" == "ovi" ]; then
        log_info "Tentando instalar flash-attn..."
        pip install flash_attn --no-build-isolation --quiet 2>/dev/null || \
            log_warn "flash_attn não instalado (modelo funcionará sem ele)"
    fi

    deactivate
    log_success "Ambiente virtual configurado!"
}

# =============================================================================
# Geração de vídeo - Ovi
# =============================================================================

generate_ovi() {
    local mode=$1
    local prompt=$2
    local image=$3
    local use_multi_gpu=$4
    local model_variant=$5

    local venv_path="${MODELS_DIR}/${MODEL_VENV[ovi]}"
    local code_dir="${MODELS_DIR}/Ovi-code"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local config_file="/tmp/ovi_config_${timestamp}.yaml"

    source "$venv_path/bin/activate"
    cd "$code_dir"

    local sp_size=1
    local cpu_offload="True"
    local fp8="True"

    # Detectar VRAM da GPU (em MB)
    local gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')

    if [ "$use_multi_gpu" == "true" ] && [ "$NUM_GPUS" -gt 1 ]; then
        # Multi-GPU só funciona com GPUs de 80GB+ (Ovi replica ~22GB em cada GPU)
        if [ "$gpu_vram" -lt 40000 ]; then
            log_warn "Multi-GPU requer GPUs com 80GB+ VRAM (atual: ${gpu_vram}MB)"
            log_warn "Forçando Single-GPU com FP8 + CPU Offload (funciona em 24GB)"
            sp_size=1
            cpu_offload="True"
            fp8="True"
        else
            sp_size=$NUM_GPUS
            cpu_offload="False"
            fp8="False"
            log_info "Usando Multi-GPU: ${NUM_GPUS} GPUs (sp_size=${sp_size})"
        fi
    else
        log_info "Usando Single-GPU com FP8 + CPU Offload (24GB VRAM)"
    fi

    local height=720
    local width=720
    case $model_variant in
        "960x960_5s"|"960x960_10s")
            height=960
            width=960
            ;;
    esac

    if [ "$mode" == "t2v" ]; then
        cat > "$config_file" << EOF
model_name: "${model_variant}"
output_dir: "${OUTPUT_DIR}"
ckpt_dir: "${MODELS_DIR}/Ovi"

sample_steps: 50
solver_name: "unipc"
shift: 5.0
seed: $RANDOM

audio_guidance_scale: 3.0
video_guidance_scale: 4.0
slg_layer: 11

sp_size: ${sp_size}
cpu_offload: ${cpu_offload}
fp8: ${fp8}

mode: "t2v"
text_prompt: "${prompt}"
video_frame_height_width: [${height}, ${width}]
each_example_n_times: 1

video_negative_prompt: "static, frozen, blur, distortion, jitter, bad hands"
audio_negative_prompt: "robotic, muffled, echo, distorted, fast, unclear"
EOF
    else
        cat > "$config_file" << EOF
model_name: "${model_variant}"
output_dir: "${OUTPUT_DIR}"
ckpt_dir: "${MODELS_DIR}/Ovi"

sample_steps: 50
solver_name: "unipc"
shift: 5.0
seed: $RANDOM

audio_guidance_scale: 3.0
video_guidance_scale: 5.0
slg_layer: 11

sp_size: ${sp_size}
cpu_offload: ${cpu_offload}
fp8: ${fp8}

mode: "i2v"
image_path: "${image}"
text_prompt: "${prompt}"
video_frame_height_width: [${height}, ${width}]
each_example_n_times: 1

video_negative_prompt: "static, frozen, still image, no movement, blur, distortion"
audio_negative_prompt: "robotic, muffled, echo, distorted, fast, unclear"
EOF
    fi

    log_info "Config: $config_file"
    log_info "Model variant: ${model_variant}"
    log_info "Iniciando geração..."
    echo ""

    if [ "$use_multi_gpu" == "true" ] && [ "$NUM_GPUS" -gt 1 ]; then
        log_info "Executando com torchrun (${NUM_GPUS} GPUs)..."
        torchrun --nnodes 1 --nproc_per_node ${NUM_GPUS} \
            inference.py --config-file "$config_file" 2>&1 | tee "${LOG_DIR}/ovi_${timestamp}.log"
    else
        python3 inference.py --config-file "$config_file" 2>&1 | tee "${LOG_DIR}/ovi_${timestamp}.log"
    fi

    deactivate

    echo ""
    log_success "Geração concluída!"
    echo ""
    log_info "Últimos vídeos gerados:"
    ls -lht "${OUTPUT_DIR}"/*.mp4 2>/dev/null | head -5
}

# =============================================================================
# Geração de vídeo - CogVideoX (T2V + I2V)
# =============================================================================

generate_cogvideox() {
    local mode=$1
    local prompt=$2
    local use_multi_gpu=$3
    local image=$4
    local venv_path="${MODELS_DIR}/${MODEL_VENV[cogvideox]}"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    source "$venv_path/bin/activate"

    if [ "$mode" == "t2v" ]; then
        log_info "Iniciando CogVideoX-5B Text-to-Video..."
    else
        log_info "Iniciando CogVideoX1.5-5B Image-to-Video..."
    fi
    log_info "Mode: $mode"
    log_info "Multi-GPU: $use_multi_gpu"

    # Build command as an array to preserve quoting
    local -a cmd_args=("$mode" "$prompt" "--output-name" "cogvideox_${mode}_${timestamp}")

    if [ "$use_multi_gpu" == "true" ] && [ "$NUM_GPUS" -gt 1 ]; then
        log_info "Usando Multi-GPU (${NUM_GPUS} GPUs)..."
        cmd_args+=("--multi-gpu")
    fi

    # Add image for I2V mode
    if [ "$mode" == "i2v" ] && [ -n "$image" ]; then
        log_info "Imagem: $image"
        cmd_args+=("--image" "$image")
    fi

    python3 "${MODELS_DIR}/CogVideoX-generate.py" "${cmd_args[@]}" 2>&1 | tee "${LOG_DIR}/cogvideox_${timestamp}.log"

    deactivate

    echo ""
    log_success "Geração concluída!"
    echo ""
    log_info "Últimos vídeos gerados:"
    ls -lht "${OUTPUT_DIR}"/cogvideox*.mp4 2>/dev/null | head -5
}

# =============================================================================
# Geração de vídeo - Wan 2.2
# =============================================================================

generate_wan() {
    local mode=$1
    local prompt=$2
    local image=$3
    local venv_path="${MODELS_DIR}/${MODEL_VENV[wan]}"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    source "$venv_path/bin/activate"

    log_info "Iniciando Wan 2.2..."

    python3 << EOF 2>&1 | tee "${LOG_DIR}/wan_${timestamp}.log"
import torch
from diffusers import WanPipeline
from diffusers.utils import export_to_video

print("Carregando modelo Wan 2.2...")
pipe = WanPipeline.from_pretrained(
    "${MODELS_DIR}/Wan2.2",
    torch_dtype=torch.bfloat16
)
pipe.enable_model_cpu_offload()

print("Gerando vídeo...")
video = pipe(
    prompt="${prompt}",
    num_frames=81,
    guidance_scale=5.0,
).frames[0]

output_path = "${OUTPUT_DIR}/wan_${timestamp}.mp4"
export_to_video(video, output_path, fps=16)
print(f"Vídeo salvo em: {output_path}")
EOF

    deactivate
    log_success "Geração concluída!"
}

# =============================================================================
# Geração de vídeo - Wan 14B Rapid
# =============================================================================

generate_wan14b() {
    local mode=$1
    local prompt=$2
    local image=$3
    local venv_path="${MODELS_DIR}/${MODEL_VENV[wan14b]}"
    local comfyui_dir="${MODELS_DIR}/ComfyUI"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    source "$venv_path/bin/activate"

    log_info "Iniciando WAN 14B Rapid (4 steps, FP8)..."
    log_info "Modo: $mode"

    # Usar o script Python de geração
    python3 "${MODELS_DIR}/Wan14B-generate.py" "$mode" "$prompt" \
        ${image:+--image "$image"} \
        --output "wan14b_${timestamp}" 2>&1 | tee "${LOG_DIR}/wan14b_${timestamp}.log"

    deactivate

    echo ""
    log_success "Geração concluída!"
    echo ""
    log_info "Últimos vídeos/imagens gerados:"
    ls -lht "${OUTPUT_DIR}"/wan14b* 2>/dev/null | head -5
}

# =============================================================================
# Geração de vídeo - HunyuanVideo-1.5
# =============================================================================
# Multi-GPU Strategies:
# 1. torchrun without offloading: Large GPUs (A100/H100 80GB+) - full speed
# 2. torchrun with offloading: Smaller GPUs (A10G 24GB) - parallelism + offloading
# 3. Single-GPU + Offloading: Fallback for single GPU setups
#
# For g5.12xlarge (4x A10G 24GB):
# - Use torchrun with 4 GPUs and offloading enabled
# - Enable cache and optimizations for faster inference
# - Expected time: ~20-30 min instead of 3+ hours with single GPU

generate_hunyuan() {
    local mode=$1
    local prompt=$2
    local image=$3
    local use_multi_gpu=$4
    local model_variant=$5  # 480p or 720p

    local venv_path="${MODELS_DIR}/${MODEL_VENV[hunyuan]}"
    local code_dir="${MODELS_DIR}/HunyuanVideo-1.5"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="${OUTPUT_DIR}/hunyuan_${mode}_${timestamp}.mp4"

    source "$venv_path/bin/activate"
    cd "$code_dir"

    # Detect GPU VRAM (in MB)
    local gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
    local total_vram=$((gpu_vram * NUM_GPUS))

    log_info "Iniciando HunyuanVideo-1.5..."
    log_info "Modo: $mode"
    log_info "Resolução: $model_variant"
    log_info "GPU VRAM: ${gpu_vram}MB x ${NUM_GPUS} GPUs = ${total_vram}MB total"

    # Set resolution based on variant
    local resolution="720p"
    if [ "$model_variant" == "480p" ]; then
        resolution="480p"
    fi

    # Determine multi-GPU strategy based on available VRAM
    # HunyuanVideo needs ~30GB for inference (16GB transformer + 14GB encoders)
    local use_torchrun="false"
    local offloading_mode="true"
    local group_offload="true"
    local overlap_offload="true"
    local enable_cache="true"  # Feature cache for faster inference
    local cfg_distilled="true"  # 2x speedup with distilled model

    if [ "$NUM_GPUS" -gt 1 ]; then
        if [ -n "$gpu_vram" ] && [ "$gpu_vram" -ge 70000 ]; then
            # Large GPUs (A100/H100 80GB+) - torchrun without offloading
            use_torchrun="true"
            offloading_mode="false"
            group_offload="false"
            overlap_offload="false"
            log_info "Estratégia: Multi-GPU torchrun SEM offloading"
            log_info "   (GPUs com ${gpu_vram}MB - modelo completo em cada GPU)"
        elif [ "$NUM_GPUS" -ge 2 ]; then
            # Multiple smaller GPUs - torchrun WITH offloading
            # 4x A10G (24GB each) - each GPU does offloading but work is parallelized
            use_torchrun="true"
            offloading_mode="true"
            group_offload="true"
            overlap_offload="true"
            log_info "Estratégia: Multi-GPU torchrun COM offloading"
            log_info "   ${NUM_GPUS} GPUs x ${gpu_vram}MB cada - trabalho paralelizado"
            log_info "   Cada processo faz offloading, mas mais rápido que single-GPU"
        fi
    else
        log_info "Usando Single-GPU com CPU offloading"
    fi

    # Set CUDA memory allocation config to prevent fragmentation
    export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,max_split_size_mb:128"

    if [ "$use_torchrun" == "true" ]; then
        # Multi-GPU with torchrun
        log_info "Executando com torchrun (${NUM_GPUS} GPUs)..."
        log_info "   Offloading: $offloading_mode"
        log_info "   Group offloading: $group_offload"
        log_info "   Overlap offloading: $overlap_offload"
        log_info "   Cache: $enable_cache"
        log_info "   CFG distilled: $cfg_distilled"

        local -a base_args=(
            "generate.py"
            "--prompt" "$prompt"
            "--resolution" "$resolution"
            "--model_path" "${code_dir}/ckpts"
            "--output_path" "$output_file"
            "--num_inference_steps" "50"
            "--seed" "$RANDOM"
            "--rewrite" "false"
            "--offloading" "$offloading_mode"
            "--group_offloading" "$group_offload"
            "--overlap_group_offloading" "$overlap_offload"
            "--enable_cache" "$enable_cache"
            "--cfg_distilled" "$cfg_distilled"
        )

        if [ "$mode" == "i2v" ] && [ -n "$image" ]; then
            base_args+=("--image_path" "$image")
        fi

        torchrun --nproc_per_node=${NUM_GPUS} "${base_args[@]}" \
            2>&1 | tee "${LOG_DIR}/hunyuan_${timestamp}.log"

    else
        # Single GPU with offloading (fallback)
        log_info "Executando com Single-GPU + CPU offloading..."
        log_warn "AVISO: Esta configuração é LENTA (~4 min/step, ~3.5h total)"
        log_warn "Considere usar --multi-gpu para distribuir entre GPUs"

        local -a base_args=(
            "generate.py"
            "--prompt" "$prompt"
            "--resolution" "$resolution"
            "--model_path" "${code_dir}/ckpts"
            "--output_path" "$output_file"
            "--num_inference_steps" "50"
            "--seed" "$RANDOM"
            "--rewrite" "false"
            "--offloading" "true"
            "--group_offloading" "true"
            "--overlap_group_offloading" "true"
        )

        if [ "$mode" == "i2v" ] && [ -n "$image" ]; then
            base_args+=("--image_path" "$image")
        fi

        python3 "${base_args[@]}" \
            2>&1 | tee "${LOG_DIR}/hunyuan_${timestamp}.log"
    fi

    deactivate

    echo ""
    log_success "Geração concluída!"
    echo ""
    log_info "Últimos vídeos gerados:"
    ls -lht "${OUTPUT_DIR}"/hunyuan*.mp4 2>/dev/null | head -5
}

# =============================================================================
# Main
# =============================================================================

main() {
    mkdir -p "$LOG_DIR"

    # Verificar se é modo interativo
    local is_interactive="false"

    # Se não há argumentos ou primeiro argumento é -i/--interactive
    if [ $# -eq 0 ] || [ "$1" == "-i" ] || [ "$1" == "--interactive" ]; then
        is_interactive="true"
    fi

    if [ "$is_interactive" == "true" ]; then
        # Modo interativo
        interactive_mode

        # Usar variáveis do modo interativo
        local model="$INTERACTIVE_MODEL"
        local mode="$INTERACTIVE_MODE"
        local prompt="$INTERACTIVE_PROMPT"
        local image="$INTERACTIVE_IMAGE"
        local model_variant="$INTERACTIVE_VARIANT"
        local use_multi_gpu="$INTERACTIVE_MULTI_GPU"
    else
        # Modo direto (parse de argumentos)
        local model=""
        local mode=""
        local prompt=""
        local image=""
        local use_multi_gpu="false"
        local model_variant="${OVI_MODEL_VARIANT}"

        while [[ $# -gt 0 ]]; do
            case $1 in
                --multi-gpu)
                    use_multi_gpu="true"
                    shift
                    ;;
                --model-variant=*)
                    model_variant="${1#*=}"
                    shift
                    ;;
                -h|--help)
                    show_usage
                    exit 0
                    ;;
                *)
                    if [ -z "$model" ]; then
                        model=$(echo "$1" | tr '[:upper:]' '[:lower:]')
                    elif [ -z "$mode" ]; then
                        mode=$(echo "$1" | tr '[:upper:]' '[:lower:]')
                    elif [ -z "$prompt" ]; then
                        prompt="$1"
                    elif [ -z "$image" ]; then
                        image="$1"
                    fi
                    shift
                    ;;
            esac
        done

        if [ -z "$model" ] || [ -z "$mode" ] || [ -z "$prompt" ]; then
            show_usage
            exit 1
        fi

        if [[ ! " ovi cogvideox wan wan14b hunyuan " =~ " $model " ]]; then
            log_error "Modelo inválido: $model"
            exit 1
        fi

        if [[ ! " t2v i2v " =~ " $mode " ]]; then
            log_error "Modo inválido: $mode"
            exit 1
        fi

        if [ "$mode" == "i2v" ] && [ -z "$image" ]; then
            log_error "Modo i2v requer uma imagem"
            exit 1
        fi

        show_banner
    fi

    echo ""
    log_info "Modelo: $model"
    log_info "Modo: $mode"
    log_info "Prompt: $prompt"
    [ -n "$image" ] && log_info "Imagem: $image"
    [ "$model" == "ovi" ] && log_info "Variant: $model_variant"
    [ "$use_multi_gpu" == "true" ] && log_info "Multi-GPU: Sim (${NUM_GPUS} GPUs)"
    echo ""

    log_step "Verificando ambiente virtual..."

    if ! check_venv_exists "$model"; then
        log_warn "Venv não encontrado. Configurando..."
        setup_venv "$model"
    elif ! check_venv_valid "$model"; then
        log_warn "Venv inválido. Reconfigurando..."
        rm -rf "${MODELS_DIR}/${MODEL_VENV[$model]}"
        setup_venv "$model"
    else
        log_success "Ambiente virtual OK!"
    fi

    # Cleanup GPU processes before starting (kills lingering ComfyUI, etc.)
    cleanup_gpu_processes

    echo ""
    log_step "Iniciando geração de vídeo..."
    echo ""

    case $model in
        ovi)
            generate_ovi "$mode" "$prompt" "$image" "$use_multi_gpu" "$model_variant"
            ;;
        cogvideox)
            generate_cogvideox "$mode" "$prompt" "$use_multi_gpu" "$image"
            ;;
        wan)
            generate_wan "$mode" "$prompt" "$image"
            ;;
        wan14b)
            generate_wan14b "$mode" "$prompt" "$image"
            ;;
        hunyuan)
            generate_hunyuan "$mode" "$prompt" "$image" "$use_multi_gpu" "$model_variant"
            ;;
    esac
}

# Executar
main "$@"
