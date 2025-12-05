#!/bin/bash

# =============================================================================
# MCP ZAP Server Management Script
# =============================================================================
# Usage:
#   ./zap.sh --install    Install and start ZAP MCP Server
#   ./zap.sh --restart    Restart all services
#   ./zap.sh --uninstall  Remove containers, images, and clean up
#   ./zap.sh --status     Show status of services
#   ./zap.sh --logs       Tail logs from services
#   ./zap.sh --stop       Stop services without removing
#   ./zap.sh --help       Show this help message
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Docker Compose project name
PROJECT_NAME="mcp-zap-server"

# =============================================================================
# Helper Functions
# =============================================================================

print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              MCP ZAP Server Management Script                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "  Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_success "Docker is installed and running"
}

# Check if Docker Compose is available
check_docker_compose() {
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        echo "  Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    print_success "Docker Compose is available"
}

# Check if .env file exists
check_env_file() {
    if [ ! -f ".env" ]; then
        print_warning ".env file not found"
        
        if [ -f ".env.example" ]; then
            print_info "Creating .env from .env.example..."
            cp .env.example .env
            print_warning "Please edit .env file with your API keys before continuing"
            echo ""
            echo "  Required variables:"
            echo "    - ZAP_API_KEY: API key for ZAP"
            echo "    - MCP_API_KEY: API key for MCP Server authentication"
            echo "    - LOCAL_ZAP_WORKPLACE_FOLDER: Path to ZAP workspace directory"
            echo ""
            exit 1
        else
            print_error ".env.example not found. Please create .env file manually."
            exit 1
        fi
    fi
    
    # Validate required variables
    source .env
    
    if [ -z "$ZAP_API_KEY" ]; then
        print_error "ZAP_API_KEY is not set in .env file"
        exit 1
    fi
    
    if [ -z "$MCP_API_KEY" ]; then
        print_error "MCP_API_KEY is not set in .env file"
        exit 1
    fi
    
    if [ -z "$LOCAL_ZAP_WORKPLACE_FOLDER" ]; then
        print_error "LOCAL_ZAP_WORKPLACE_FOLDER is not set in .env file"
        exit 1
    fi
    
    print_success "Environment configuration validated"
}

# Check if services are running
is_running() {
    local running=$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')
    [ "$running" -gt 0 ]
}

# Get container status
get_status() {
    docker compose ps -a 2>/dev/null
}

# Wait for services to be healthy
wait_for_healthy() {
    local timeout=120
    local elapsed=0
    
    print_info "Waiting for services to be healthy..."
    
    while [ $elapsed -lt $timeout ]; do
        local healthy=$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')
        local expected=2  # zap and mcp-server
        
        if [ "$healthy" -eq "$expected" ]; then
            # Check if mcp-server health check passes
            if docker compose exec -T mcp-server curl -sf http://localhost:7456/actuator/health &>/dev/null; then
                print_success "All services are healthy"
                return 0
            fi
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        echo -ne "\r  Elapsed: ${elapsed}s / ${timeout}s"
    done
    
    echo ""
    print_warning "Timeout waiting for services. Check logs with: ./zap.sh --logs"
    return 1
}

# =============================================================================
# Command Functions
# =============================================================================

cmd_install() {
    print_banner
    echo "Installing MCP ZAP Server..."
    echo ""
    
    # Check prerequisites
    check_docker
    check_docker_compose
    check_env_file
    
    echo ""
    
    # Check if already running
    if is_running; then
        print_warning "Services are already running!"
        echo ""
        get_status
        echo ""
        print_info "Use './zap.sh --restart' to restart services"
        print_info "Use './zap.sh --status' to check status"
        exit 0
    fi
    
    # Create workspace directory
    source .env
    if [ ! -d "$LOCAL_ZAP_WORKPLACE_FOLDER/zap-wrk" ]; then
        print_info "Creating workspace directory: $LOCAL_ZAP_WORKPLACE_FOLDER/zap-wrk"
        mkdir -p "$LOCAL_ZAP_WORKPLACE_FOLDER/zap-wrk"
        mkdir -p "$LOCAL_ZAP_WORKPLACE_FOLDER/zap-home"
    fi
    
    # Build and start services
    print_info "Building and starting services..."
    echo ""
    
    docker compose build
    docker compose up -d
    
    echo ""
    
    # Wait for services to be healthy
    wait_for_healthy
    
    echo ""
    print_success "Installation complete!"
    echo ""
    echo "  MCP Server:  http://localhost:7456/mcp"
    echo "  ZAP API:     http://localhost:8091"
    echo "  Health:      http://localhost:7456/actuator/health"
    echo ""
    echo "  Test with:"
    echo "    curl -X POST http://localhost:7456/mcp \\"
    echo "      -H 'Content-Type: application/json' \\"
    echo "      -H 'Authorization: Bearer \$MCP_API_KEY' \\"
    echo "      -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}'"
    echo ""
}

cmd_restart() {
    print_banner
    echo "Restarting MCP ZAP Server..."
    echo ""
    
    check_docker
    check_docker_compose
    
    if ! is_running; then
        print_warning "Services are not running. Starting fresh..."
        cmd_install
        return
    fi
    
    print_info "Restarting services..."
    docker compose restart
    
    echo ""
    wait_for_healthy
    
    echo ""
    print_success "Restart complete!"
    echo ""
}

cmd_stop() {
    print_banner
    echo "Stopping MCP ZAP Server..."
    echo ""
    
    check_docker
    check_docker_compose
    
    if ! is_running; then
        print_warning "Services are not running"
        exit 0
    fi
    
    print_info "Stopping services..."
    docker compose stop
    
    echo ""
    print_success "Services stopped"
    print_info "Use './zap.sh --install' to start again"
    echo ""
}

cmd_uninstall() {
    print_banner
    echo "Uninstalling MCP ZAP Server..."
    echo ""
    
    check_docker
    check_docker_compose
    
    # Confirmation prompt
    echo -e "${YELLOW}⚠ WARNING: This will remove:${NC}"
    echo "  - All containers"
    echo "  - Built images (mcp-zap-server:latest)"
    echo "  - Docker networks"
    echo ""
    echo -e "${RED}Note: ZAP workspace data in LOCAL_ZAP_WORKPLACE_FOLDER will NOT be deleted${NC}"
    echo ""
    
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled"
        exit 0
    fi
    
    echo ""
    
    # Stop and remove containers
    print_info "Stopping and removing containers..."
    docker compose down --remove-orphans 2>/dev/null || true
    
    # Remove built images
    print_info "Removing built images..."
    docker rmi mcp-zap-server:latest 2>/dev/null || true
    
    # Remove dangling images from build
    print_info "Cleaning up dangling images..."
    docker image prune -f 2>/dev/null || true
    
    echo ""
    print_success "Uninstall complete!"
    echo ""
    print_info "ZAP workspace data was preserved. To remove manually:"
    
    if [ -f ".env" ]; then
        source .env
        echo "  rm -rf $LOCAL_ZAP_WORKPLACE_FOLDER"
    else
        echo "  rm -rf \$LOCAL_ZAP_WORKPLACE_FOLDER"
    fi
    echo ""
}

cmd_status() {
    print_banner
    echo "MCP ZAP Server Status"
    echo ""
    
    check_docker
    check_docker_compose
    
    if is_running; then
        print_success "Services are running"
    else
        print_warning "Services are not running"
    fi
    
    echo ""
    get_status
    echo ""
    
    # Show endpoints if running
    if is_running; then
        echo "Endpoints:"
        echo "  MCP Server:  http://localhost:7456/mcp"
        echo "  ZAP API:     http://localhost:8091"
        echo "  Health:      http://localhost:7456/actuator/health"
        echo ""
    fi
}

cmd_logs() {
    check_docker
    check_docker_compose
    
    if ! is_running; then
        print_warning "Services are not running"
        exit 1
    fi
    
    print_info "Tailing logs (Ctrl+C to exit)..."
    echo ""
    docker compose logs -f
}

cmd_help() {
    print_banner
    echo "Usage: ./zap.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  --install     Install and start ZAP MCP Server"
    echo "  --restart     Restart all services"
    echo "  --stop        Stop services without removing"
    echo "  --uninstall   Remove containers, images, and clean up"
    echo "  --status      Show status of services"
    echo "  --logs        Tail logs from services"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./zap.sh --install      # First time setup"
    echo "  ./zap.sh --status       # Check if running"
    echo "  ./zap.sh --logs         # View logs"
    echo "  ./zap.sh --restart      # Restart services"
    echo "  ./zap.sh --uninstall    # Clean up everything"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

case "${1:-}" in
    --install|-i)
        cmd_install
        ;;
    --restart|-r)
        cmd_restart
        ;;
    --stop|-s)
        cmd_stop
        ;;
    --uninstall|-u)
        cmd_uninstall
        ;;
    --status)
        cmd_status
        ;;
    --logs|-l)
        cmd_logs
        ;;
    --help|-h|"")
        cmd_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        cmd_help
        exit 1
        ;;
esac
