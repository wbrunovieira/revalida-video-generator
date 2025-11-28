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
)

declare -A MODEL_TORCH=(
    ["ovi"]="torch==2.6.0 torchvision torchaudio"
    ["cogvideox"]="torch torchvision torchaudio"
    ["wan"]="torch torchvision torchaudio"
    ["wan14b"]="torch torchvision torchaudio"
)

declare -A MODEL_CODE_DIR=(
    ["ovi"]="Ovi-code"
    ["cogvideox"]="CogVideoX-5b"
    ["wan"]="Wan2.2"
    ["wan14b"]="ComfyUI"
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

show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║          🎬 Video Generation - Revalida Italia 🎬             ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║  Modelos disponíveis:                                         ║"
    echo "║    • ovi       - Video + Audio sincronizado (T2V/I2V)        ║"
    echo "║    • cogvideox - Alta qualidade, multi-GPU (T2V)             ║"
    echo "║    • wan       - Versátil, T2V + I2V                         ║"
    echo "║    • wan14b    - Ultra-rápido 4 steps! (T2V/I2V) [NOVO]      ║"
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
    echo "   3) wan       - Versátil"
    echo "   4) wan14b    - Ultra-rápido (4 steps!) [NOVO]"
    echo ""
    read -p "   Modelo [1-4, default=1]: " model_choice
    case "$model_choice" in
        2) MODEL="cogvideox" ;;
        3) MODEL="wan" ;;
        4) MODEL="wan14b" ;;
        *) MODEL="ovi" ;;
    esac
    echo -e "   ${GREEN}✓ Modelo: ${MODEL}${NC}"
    echo ""

    # 2. Escolher modo (T2V ou I2V)
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
    else
        # Outros modelos (cogvideox, wan)
        if [ "$NUM_GPUS" -gt 1 ]; then
            echo -e "${YELLOW}4. Usar Multi-GPU? (${NUM_GPUS} GPUs disponíveis)${NC}"
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
# Geração de vídeo - CogVideoX
# =============================================================================

generate_cogvideox() {
    local mode=$1
    local prompt=$2
    local venv_path="${MODELS_DIR}/${MODEL_VENV[cogvideox]}"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    source "$venv_path/bin/activate"

    log_info "Iniciando CogVideoX..."

    python3 << EOF 2>&1 | tee "${LOG_DIR}/cogvideox_${timestamp}.log"
import torch
from diffusers import CogVideoXPipeline
from diffusers.utils import export_to_video

print("Carregando modelo CogVideoX-5b...")
pipe = CogVideoXPipeline.from_pretrained(
    "${MODELS_DIR}/CogVideoX-5b",
    torch_dtype=torch.bfloat16
)
pipe.enable_model_cpu_offload()
pipe.vae.enable_tiling()

print("Gerando vídeo...")
video = pipe(
    prompt="${prompt}",
    num_videos_per_prompt=1,
    num_inference_steps=50,
    num_frames=49,
    guidance_scale=6,
).frames[0]

output_path = "${OUTPUT_DIR}/cogvideox_${timestamp}.mp4"
export_to_video(video, output_path, fps=8)
print(f"Vídeo salvo em: {output_path}")
EOF

    deactivate
    log_success "Geração concluída!"
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

        if [[ ! " ovi cogvideox wan wan14b " =~ " $model " ]]; then
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

    echo ""
    log_step "Iniciando geração de vídeo..."
    echo ""

    case $model in
        ovi)
            generate_ovi "$mode" "$prompt" "$image" "$use_multi_gpu" "$model_variant"
            ;;
        cogvideox)
            generate_cogvideox "$mode" "$prompt"
            ;;
        wan)
            generate_wan "$mode" "$prompt" "$image"
            ;;
        wan14b)
            generate_wan14b "$mode" "$prompt" "$image"
            ;;
    esac
}

# Executar
main "$@"
