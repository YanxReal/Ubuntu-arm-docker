# ============================================================================
#  Ubuntu ARM Docker — escritorio Cinnamon (X11) en arm64
#  Atajos: `make` muestra la ayuda, `make install` lo pone todo en marcha.
# ============================================================================

SHELL   := /bin/bash
COMPOSE ?= docker compose
SERVICE ?= ubuntu-desktop

# Carga .env si existe (para reutilizar puertos y contraseñas en los mensajes)
-include .env
export

.DEFAULT_GOAL := help

.PHONY: help install build up down restart status logs logs-x11vnc shell ssh dev assistant reload destroy update

help: ## Muestra esta ayuda
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1mUbuntu ARM Docker\033[0m — comandos disponibles:\n\n"} \
	     /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@printf "  Primer paso:  \033[1mmake install\033[0m\n\n"

install: ## Construye y arranca todo (primer uso)
	@test -f .env || cp .env.example .env
	@docker info >/dev/null 2>&1 || { echo "❌ Docker no está en marcha. Ábrelo y reintenta."; exit 1; }
	$(COMPOSE) build
	$(COMPOSE) up -d
	@echo "⏳ Esperando a que el escritorio arranque..."
	@for i in $$(seq 1 60); do \
		code=$$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$${NOVNC_HOST_PORT:-6080}/vnc.html" 2>/dev/null || true); \
		[ "$$code" = "200" ] && break; \
		sleep 2; \
	done
	@echo ""
	@echo "✅ Todo listo. Accede así:"
	@echo "   • noVNC : http://localhost:$${NOVNC_HOST_PORT:-6080}/vnc.html   (contraseña: $${VNC_PASSWORD:-admin})"
	@echo "   • VNC   : localhost:$${VNC_HOST_PORT:-5902}                    (contraseña: $${VNC_PASSWORD:-admin})"
	@echo "   • SSH   : ssh admin@localhost -p $${SSH_HOST_PORT:-2222}       (password: admin)"
	@echo ""

build: ## (Re)construye la imagen Docker
	@test -f .env || cp .env.example .env
	$(COMPOSE) build

up: ## Arranca el contenedor
	@test -f .env || cp .env.example .env
	$(COMPOSE) up -d

down: ## Para y elimina el contenedor (el home se conserva)
	$(COMPOSE) down

restart: down up ## Reinicia el contenedor

status: ## Muestra el estado y comprueba noVNC
	@$(COMPOSE) ps
	@printf "noVNC  -> http://localhost:%s/vnc.html : %s\n" "$${NOVNC_HOST_PORT:-6080}" \
		"$$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$${NOVNC_HOST_PORT:-6080}/vnc.html 2>/dev/null || echo 'sin respuesta')"

logs: ## Logs en directo del contenedor
	$(COMPOSE) logs -f

logs-x11vnc: ## Log del servidor X/Cinnamon/x11vnc (session.log)
	@$(COMPOSE) exec -T $(SERVICE) tail -n 100 /run/user/1000/session.log 2>/dev/null || echo "Sin log todavía."

shell: ## Shell como admin dentro del contenedor
	$(COMPOSE) exec -u admin $(SERVICE) bash

ssh: ## Abre SSH contra el contenedor
	ssh -p $${SSH_HOST_PORT:-2222} admin@localhost

dev: ## Lanza una app gráfica:  make dev ARGS="gnome-terminal"
	@test -n "$(ARGS)" || { echo 'Uso: make dev ARGS="gnome-terminal"'; exit 1; }
	$(COMPOSE) exec -d -u admin $(SERVICE) dev $(ARGS)

assistant: ## Control de escritorio para la IA:  make assistant ARGS="shot"
	@$(COMPOSE) exec -T -u admin $(SERVICE) assistant $(ARGS)

reload: down build up ## Reconstruye desde cero y arranca

destroy: ## Borra contenedor, redes y el home persistente (¡cuidado!)
	$(COMPOSE) down -v

update: ## Actualiza el repo y reinstala
	git pull
	$(MAKE) install
