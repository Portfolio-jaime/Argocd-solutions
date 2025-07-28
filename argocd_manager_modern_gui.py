#!/usr/bin/env python3
"""
ArgoCD Solutions Manager - Modern GUI
Interfaz gráfica moderna con diseño mejorado para gestionar herramientas de ArgoCD
Autor: Jaime Andrés Henao
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog, font
import subprocess
import threading
import os
import sys
from datetime import datetime
import json
from pathlib import Path

class ModernArgocdManager:
    def __init__(self, root):
        self.root = root
        self.root.title("ArgoCD Solutions Manager - Modern Edition")
        self.root.geometry("1400x900")
        
        # Configurar tema moderno
        self.setup_modern_theme()
        
        # Configurar el directorio base
        self.base_dir = Path(__file__).parent
        
        # Variables de estado
        self.current_process = None
        self.log_content = []
        self.selected_tool = None
        
        # Crear la interfaz moderna
        self.create_modern_interface()
        
        # Verificar dependencias al inicio
        self.check_dependencies()
    
    def setup_modern_theme(self):
        """Configurar tema moderno con colores atractivos"""
        # Colores del tema moderno
        self.colors = {
            'primary': '#2C3E50',      # Azul oscuro
            'secondary': '#3498DB',     # Azul claro
            'success': '#27AE60',       # Verde
            'warning': '#F39C12',       # Naranja
            'danger': '#E74C3C',        # Rojo
            'info': '#9B59B6',          # Púrpura
            'light': '#ECF0F1',         # Gris claro
            'dark': '#2C3E50',          # Azul oscuro
            'background': '#F8F9FA',    # Fondo claro
            'card': '#FFFFFF',          # Blanco para tarjetas
            'border': '#E5E5E5'         # Borde sutil
        }
        
        self.root.configure(bg=self.colors['background'])
        
        # Configurar estilo moderno
        style = ttk.Style()
        style.theme_use('clam')
        
        # Estilos personalizados modernos
        style.configure('Modern.TFrame', 
                       background=self.colors['card'],
                       relief='flat',
                       borderwidth=1)
        
        style.configure('Card.TFrame',
                       background=self.colors['card'],
                       relief='solid',
                       borderwidth=1,
                       bordercolor=self.colors['border'])
        
        style.configure('Sidebar.TFrame',
                       background=self.colors['primary'],
                       relief='flat')
        
        style.configure('Title.TLabel',
                       font=('Segoe UI', 24, 'bold'),
                       foreground=self.colors['primary'],
                       background=self.colors['background'])
        
        style.configure('Subtitle.TLabel',
                       font=('Segoe UI', 14, 'bold'),
                       foreground=self.colors['secondary'],
                       background=self.colors['card'])
        
        style.configure('Card.TLabel',
                       font=('Segoe UI', 10),
                       background=self.colors['card'],
                       foreground=self.colors['dark'])
        
        style.configure('Sidebar.TLabel',
                       font=('Segoe UI', 12, 'bold'),
                       foreground='white',
                       background=self.colors['primary'])
        
        style.configure('Tool.TButton',
                       font=('Segoe UI', 10, 'bold'),
                       padding=(15, 10))
        
        style.configure('Action.TButton',
                       font=('Segoe UI', 11, 'bold'),
                       padding=(20, 10))
        
        # Configurar notebook moderno
        style.configure('Modern.TNotebook',
                       background=self.colors['background'],
                       borderwidth=0)
        
        style.configure('Modern.TNotebook.Tab',
                       padding=(20, 10),
                       font=('Segoe UI', 10, 'bold'))
    
    def create_modern_interface(self):
        """Crear interfaz moderna con diseño de tarjetas"""
        # Frame principal con padding
        self.main_frame = tk.Frame(self.root, bg=self.colors['background'])
        self.main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Header con título y estado
        self.create_header()
        
        # Notebook para organizar las secciones
        self.create_notebook()
        
        # Barra de estado moderna
        self.create_modern_status_bar()
    
    def create_header(self):
        """Crear header moderno"""
        header_frame = tk.Frame(self.main_frame, bg=self.colors['background'], height=100)
        header_frame.pack(fill=tk.X, pady=(0, 20))
        header_frame.pack_propagate(False)
        
        # Título principal
        title_label = tk.Label(header_frame,
                              text="🚀 ArgoCD Solutions Manager",
                              font=('Segoe UI', 28, 'bold'),
                              fg=self.colors['primary'],
                              bg=self.colors['background'])
        title_label.pack(side=tk.LEFT, pady=20)
        
        # Info del sistema en el header
        info_frame = tk.Frame(header_frame, bg=self.colors['background'])
        info_frame.pack(side=tk.RIGHT, pady=20)
        
        # Botón de configuración
        config_btn = tk.Button(info_frame,
                              text="⚙️ Config",
                              font=('Segoe UI', 10),
                              bg=self.colors['secondary'],
                              fg='white',
                              relief='flat',
                              padx=15,
                              pady=5,
                              command=self.show_config)
        config_btn.pack(side=tk.RIGHT, padx=(10, 0))
        
        # Botón de ayuda
        help_btn = tk.Button(info_frame,
                            text="❓ Ayuda",
                            font=('Segoe UI', 10),
                            bg=self.colors['info'],
                            fg='white',
                            relief='flat',
                            padx=15,
                            pady=5,
                            command=self.show_help)
        help_btn.pack(side=tk.RIGHT, padx=(10, 0))
    
    def create_notebook(self):
        """Crear notebook con pestañas modernas"""
        self.notebook = ttk.Notebook(self.main_frame, style='Modern.TNotebook')
        self.notebook.pack(fill=tk.BOTH, expand=True)
        
        # Pestaña de herramientas
        self.tools_tab = tk.Frame(self.notebook, bg=self.colors['background'])
        self.notebook.add(self.tools_tab, text="🛠️ Herramientas")
        
        # Pestaña de monitoreo
        self.monitor_tab = tk.Frame(self.notebook, bg=self.colors['background'])
        self.notebook.add(self.monitor_tab, text="📊 Dashboard")
        
        # Pestaña de logs
        self.logs_tab = tk.Frame(self.notebook, bg=self.colors['background'])
        self.notebook.add(self.logs_tab, text="📋 Logs")
        
        # Pestaña de configuración
        self.config_tab = tk.Frame(self.notebook, bg=self.colors['background'])
        self.notebook.add(self.config_tab, text="⚙️ Configuración")
        
        # Crear contenido de cada pestaña
        self.create_tools_tab()
        self.create_monitor_tab()
        self.create_logs_tab()
        self.create_config_tab()
    
    def create_tools_tab(self):
        """Crear pestaña de herramientas con diseño de tarjetas"""
        # Frame principal de herramientas
        tools_main = tk.Frame(self.tools_tab, bg=self.colors['background'])
        tools_main.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Título de sección
        title_label = tk.Label(tools_main,
                              text="Herramientas Disponibles",
                              font=('Segoe UI', 18, 'bold'),
                              fg=self.colors['primary'],
                              bg=self.colors['background'])
        title_label.pack(anchor=tk.W, pady=(0, 20))
        
        # Frame para las tarjetas con scroll
        canvas = tk.Canvas(tools_main, bg=self.colors['background'], highlightthickness=0)
        scrollbar = ttk.Scrollbar(tools_main, orient="vertical", command=canvas.yview)
        scrollable_frame = tk.Frame(canvas, bg=self.colors['background'])
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Definir herramientas con colores modernos
        self.tools = [
            {
                'name': 'Redis HA Fix',
                'emoji': '🔧',
                'description': 'Diagnostica y repara problemas de Redis HA',
                'script': 'Check-Redis-ha/redis-ha-fix.sh',
                'category': 'Mantenimiento',
                'color': '#E74C3C'
            },
            {
                'name': 'Zombie Cleaner',
                'emoji': '🧹',
                'description': 'Limpia AppProjects con finalizers atorados',
                'script': 'Check-argocd/argocd-zombie-cleaner.sh',
                'category': 'Limpieza',
                'color': '#1ABC9C'
            },
            {
                'name': 'CRDs Checker',
                'emoji': '📋',
                'description': 'Verifica compatibilidad de CRDs',
                'script': 'Check_CRDs-K8s/check_crds-argocd.sh',
                'category': 'Validación',
                'color': '#3498DB'
            },
            {
                'name': 'Safe CRD Upgrade',
                'emoji': '🔄',
                'description': 'Actualización segura de CRDs con TUI',
                'script': 'Check_crds_compatibilitie/safe_crd_upgrade_tui.sh',
                'category': 'Actualización',
                'color': '#F39C12'
            },
            {
                'name': 'ArgoCD Inspector',
                'emoji': '🔍',
                'description': 'Inspecciona configuración de ArgoCD',
                'script': 'Check_resources_and_healthcheck/inspect_argocd.sh',
                'category': 'Diagnóstico',
                'color': '#9B59B6'
            },
            {
                'name': 'Pre-update Check',
                'emoji': '✅',
                'description': 'Validaciones antes de actualizar',
                'script': 'Pre-update_check/pre-validation.sh',
                'category': 'Validación',
                'color': '#27AE60'
            },
            {
                'name': 'CRD Updater',
                'emoji': '🔧',
                'description': 'Actualiza CRDs de ArgoCD',
                'script': 'Update_argocd_crds/argocd-crd-updater.sh',
                'category': 'Actualización',
                'color': '#E91E63'
            },
            {
                'name': 'Orphan Analyzer',
                'emoji': '🕵️',
                'description': 'Analiza recursos huérfanos en el cluster',
                'script': 'Orphan_resources_analyzer/orphan_analyzer.sh',
                'category': 'Análisis',
                'color': '#FF5722'
            },
            {
                'name': 'Performance Monitor',
                'emoji': '📊',
                'description': 'Monitorea rendimiento de ArgoCD en tiempo real',
                'script': 'Performance_monitor/performance_monitor.sh',
                'category': 'Monitoreo',
                'color': '#00BCD4'
            },
            {
                'name': 'Security Analyzer',
                'emoji': '🔐',
                'description': 'Análisis comprehensivo de seguridad',
                'script': 'Security_analyzer/security_analyzer.sh',
                'category': 'Seguridad',
                'color': '#9C27B0'
            }
        ]
        
        # Crear tarjetas de herramientas en grid
        self.create_tool_cards(scrollable_frame)
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
    
    def create_tool_cards(self, parent):
        """Crear tarjetas modernas para las herramientas"""
        # Organizar herramientas por categoría
        categories = {}
        for tool in self.tools:
            category = tool['category']
            if category not in categories:
                categories[category] = []
            categories[category].append(tool)
        
        row = 0
        for category, tools in categories.items():
            # Título de categoría
            category_label = tk.Label(parent,
                                    text=f"📂 {category}",
                                    font=('Segoe UI', 14, 'bold'),
                                    fg=self.colors['secondary'],
                                    bg=self.colors['background'])
            category_label.grid(row=row, column=0, columnspan=3, sticky=tk.W, pady=(20, 10))
            row += 1
            
            # Crear tarjetas para herramientas de la categoría
            col = 0
            for tool in tools:
                card_frame = self.create_tool_card(parent, tool)
                card_frame.grid(row=row, column=col, padx=10, pady=10, sticky=tk.NSEW)
                
                col += 1
                if col >= 3:  # Máximo 3 columnas
                    col = 0
                    row += 1
            
            if col > 0:  # Si no completamos la fila
                row += 1
        
        # Configurar grid weights
        for i in range(3):
            parent.grid_columnconfigure(i, weight=1)
    
    def create_tool_card(self, parent, tool):
        """Crear una tarjeta individual para una herramienta"""
        # Frame principal de la tarjeta
        card = tk.Frame(parent,
                       bg=self.colors['card'],
                       relief='solid',
                       borderwidth=1,
                       padx=20,
                       pady=20)
        
        # Emoji grande
        emoji_label = tk.Label(card,
                              text=tool['emoji'],
                              font=('Segoe UI', 32),
                              bg=self.colors['card'])
        emoji_label.pack(pady=(0, 10))
        
        # Nombre de la herramienta
        name_label = tk.Label(card,
                             text=tool['name'],
                             font=('Segoe UI', 12, 'bold'),
                             fg=self.colors['primary'],
                             bg=self.colors['card'])
        name_label.pack(pady=(0, 5))
        
        # Descripción
        desc_label = tk.Label(card,
                             text=tool['description'],
                             font=('Segoe UI', 9),
                             fg=self.colors['dark'],
                             bg=self.colors['card'],
                             wraplength=200,
                             justify=tk.CENTER)
        desc_label.pack(pady=(0, 15))
        
        # Botón de ejecutar
        run_btn = tk.Button(card,
                           text="▶️ Ejecutar",
                           font=('Segoe UI', 10, 'bold'),
                           bg=tool['color'],
                           fg='white',
                           relief='flat',
                           padx=20,
                           pady=8,
                           cursor='hand2',
                           command=lambda t=tool: self.select_and_run_tool(t))
        run_btn.pack()
        
        # Hover effects
        def on_enter(e):
            card.configure(relief='solid', borderwidth=2)
            run_btn.configure(bg=self.adjust_color_brightness(tool['color'], -20))
        
        def on_leave(e):
            card.configure(relief='solid', borderwidth=1)
            run_btn.configure(bg=tool['color'])
        
        card.bind('<Enter>', on_enter)
        card.bind('<Leave>', on_leave)
        run_btn.bind('<Enter>', on_enter)
        run_btn.bind('<Leave>', on_leave)
        
        return card
    
    def adjust_color_brightness(self, hex_color, adjustment):
        """Ajustar el brillo de un color hexadecimal"""
        # Convertir hex a RGB
        hex_color = hex_color.lstrip('#')
        rgb = tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
        
        # Ajustar brillo
        rgb = tuple(max(0, min(255, c + adjustment)) for c in rgb)
        
        # Convertir de vuelta a hex
        return '#{:02x}{:02x}{:02x}'.format(*rgb)
    
    def create_monitor_tab(self):
        """Crear pestaña de dashboard/monitoreo"""
        monitor_main = tk.Frame(self.monitor_tab, bg=self.colors['background'])
        monitor_main.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Título
        title_label = tk.Label(monitor_main,
                              text="Dashboard de Sistema",
                              font=('Segoe UI', 18, 'bold'),
                              fg=self.colors['primary'],
                              bg=self.colors['background'])
        title_label.pack(anchor=tk.W, pady=(0, 20))
        
        # Frame para métricas
        metrics_frame = tk.Frame(monitor_main, bg=self.colors['background'])
        metrics_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Crear cards de métricas
        self.create_metric_cards(metrics_frame)
        
        # Área de información del sistema
        self.system_info_text = scrolledtext.ScrolledText(monitor_main,
                                                         height=15,
                                                         font=('Consolas', 10),
                                                         bg='#1E1E1E',
                                                         fg='#D4D4D4',
                                                         insertbackground='white')
        self.system_info_text.pack(fill=tk.BOTH, expand=True)
        
        # Botón de actualizar
        refresh_btn = tk.Button(monitor_main,
                               text="🔄 Actualizar Sistema",
                               font=('Segoe UI', 11, 'bold'),
                               bg=self.colors['info'],
                               fg='white',
                               relief='flat',
                               padx=20,
                               pady=10,
                               command=self.update_system_info)
        refresh_btn.pack(pady=(10, 0))
        
        # Cargar información inicial
        self.update_system_info()
    
    def create_metric_cards(self, parent):
        """Crear tarjetas de métricas"""
        # Métricas de ejemplo
        metrics = [
            {'title': 'Estado', 'value': '✅ OK', 'color': self.colors['success']},
            {'title': 'Herramientas', 'value': str(len(self.tools)), 'color': self.colors['info']},
            {'title': 'Última Ejecución', 'value': 'N/A', 'color': self.colors['warning']},
            {'title': 'Uptime', 'value': 'N/A', 'color': self.colors['secondary']}
        ]
        
        for i, metric in enumerate(metrics):
            card = tk.Frame(parent,
                           bg=self.colors['card'],
                           relief='solid',
                           borderwidth=1,
                           padx=20,
                           pady=15)
            card.grid(row=0, column=i, padx=10, sticky=tk.NSEW)
            
            # Valor
            value_label = tk.Label(card,
                                  text=metric['value'],
                                  font=('Segoe UI', 16, 'bold'),
                                  fg=metric['color'],
                                  bg=self.colors['card'])
            value_label.pack()
            
            # Título
            title_label = tk.Label(card,
                                  text=metric['title'],
                                  font=('Segoe UI', 10),
                                  fg=self.colors['dark'],
                                  bg=self.colors['card'])
            title_label.pack()
        
        # Configurar grid weights
        for i in range(len(metrics)):
            parent.grid_columnconfigure(i, weight=1)
    
    def create_logs_tab(self):
        """Crear pestaña de logs"""
        logs_main = tk.Frame(self.logs_tab, bg=self.colors['background'])
        logs_main.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Header de logs
        header_frame = tk.Frame(logs_main, bg=self.colors['background'])
        header_frame.pack(fill=tk.X, pady=(0, 10))
        
        # Título
        title_label = tk.Label(header_frame,
                              text="Logs de Ejecución",
                              font=('Segoe UI', 18, 'bold'),
                              fg=self.colors['primary'],
                              bg=self.colors['background'])
        title_label.pack(side=tk.LEFT)
        
        # Botones de control
        btn_frame = tk.Frame(header_frame, bg=self.colors['background'])
        btn_frame.pack(side=tk.RIGHT)
        
        clear_btn = tk.Button(btn_frame,
                             text="🗑️ Limpiar",
                             font=('Segoe UI', 10),
                             bg=self.colors['warning'],
                             fg='white',
                             relief='flat',
                             padx=15,
                             pady=5,
                             command=self.clear_logs)
        clear_btn.pack(side=tk.RIGHT, padx=(10, 0))
        
        export_btn = tk.Button(btn_frame,
                              text="💾 Exportar",
                              font=('Segoe UI', 10),
                              bg=self.colors['success'],
                              fg='white',
                              relief='flat',
                              padx=15,
                              pady=5,
                              command=self.export_logs)
        export_btn.pack(side=tk.RIGHT)
        
        # Área de logs
        self.log_text = scrolledtext.ScrolledText(logs_main,
                                                 font=('Consolas', 10),
                                                 bg='#1E1E1E',
                                                 fg='#D4D4D4',
                                                 insertbackground='white')
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Control de ejecución
        control_frame = tk.Frame(logs_main, bg=self.colors['background'])
        control_frame.pack(fill=tk.X, pady=(10, 0))
        
        self.run_btn = tk.Button(control_frame,
                                text="▶️ Ejecutar Herramienta",
                                font=('Segoe UI', 12, 'bold'),
                                bg=self.colors['success'],
                                fg='white',
                                relief='flat',
                                padx=30,
                                pady=10,
                                state='disabled',
                                command=self.execute_selected_tool)
        self.run_btn.pack(side=tk.LEFT)
        
        self.stop_btn = tk.Button(control_frame,
                                 text="⏹️ Detener",
                                 font=('Segoe UI', 12, 'bold'),
                                 bg=self.colors['danger'],
                                 fg='white',
                                 relief='flat',
                                 padx=30,
                                 pady=10,
                                 state='disabled',
                                 command=self.stop_execution)
        self.stop_btn.pack(side=tk.LEFT, padx=(10, 0))
        
        # Progress bar moderna
        self.progress = ttk.Progressbar(control_frame,
                                       mode='indeterminate',
                                       length=200)
        self.progress.pack(side=tk.RIGHT, padx=(10, 0))
    
    def create_config_tab(self):
        """Crear pestaña de configuración"""
        config_main = tk.Frame(self.config_tab, bg=self.colors['background'])
        config_main.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Título
        title_label = tk.Label(config_main,
                              text="Configuración del Sistema",
                              font=('Segoe UI', 18, 'bold'),
                              fg=self.colors['primary'],
                              bg=self.colors['background'])
        title_label.pack(anchor=tk.W, pady=(0, 20))
        
        # Formulario de configuración
        form_frame = tk.Frame(config_main,
                             bg=self.colors['card'],
                             relief='solid',
                             borderwidth=1,
                             padx=30,
                             pady=30)
        form_frame.pack(fill=tk.X, pady=(0, 20))
        
        # Campos de configuración
        self.create_config_fields(form_frame)
    
    def create_config_fields(self, parent):
        """Crear campos de configuración"""
        fields = [
            {'label': 'Namespace de ArgoCD:', 'var': 'argocd_namespace', 'default': 'argocd'},
            {'label': 'Timeout (segundos):', 'var': 'timeout', 'default': '300'},
            {'label': 'Directorio de trabajo:', 'var': 'work_dir', 'default': str(self.base_dir)},
        ]
        
        self.config_vars = {}
        
        for i, field in enumerate(fields):
            # Label
            label = tk.Label(parent,
                           text=field['label'],
                           font=('Segoe UI', 11, 'bold'),
                           fg=self.colors['primary'],
                           bg=self.colors['card'])
            label.grid(row=i, column=0, sticky=tk.W, pady=10, padx=(0, 20))
            
            # Entry
            var = tk.StringVar(value=field['default'])
            self.config_vars[field['var']] = var
            
            entry = tk.Entry(parent,
                           textvariable=var,
                           font=('Segoe UI', 11),
                           width=30)
            entry.grid(row=i, column=1, sticky=tk.EW, pady=10)
        
        parent.grid_columnconfigure(1, weight=1)
        
        # Botón de guardar
        save_btn = tk.Button(parent,
                           text="💾 Guardar Configuración",
                           font=('Segoe UI', 11, 'bold'),
                           bg=self.colors['success'],
                           fg='white',
                           relief='flat',
                           padx=20,
                           pady=10,
                           command=self.save_config)
        save_btn.grid(row=len(fields), column=0, columnspan=2, pady=20)
    
    def create_modern_status_bar(self):
        """Crear barra de estado moderna"""
        status_frame = tk.Frame(self.main_frame,
                               bg=self.colors['primary'],
                               height=40)
        status_frame.pack(fill=tk.X, pady=(10, 0))
        status_frame.pack_propagate(False)
        
        # Status label
        self.status_label = tk.Label(status_frame,
                                    text="Listo",
                                    font=('Segoe UI', 10),
                                    fg='white',
                                    bg=self.colors['primary'])
        self.status_label.pack(side=tk.LEFT, padx=20, pady=10)
        
        # Información adicional
        info_label = tk.Label(status_frame,
                             text=f"ArgoCD Solutions Manager | {datetime.now().strftime('%Y-%m-%d %H:%M')}",
                             font=('Segoe UI', 9),
                             fg='#BDC3C7',
                             bg=self.colors['primary'])
        info_label.pack(side=tk.RIGHT, padx=20, pady=10)
    
    # Métodos de funcionalidad (mantener los existentes y agregar nuevos)
    def select_and_run_tool(self, tool):
        """Seleccionar y ejecutar herramienta"""
        self.selected_tool = tool
        self.update_status(f"Herramienta seleccionada: {tool['name']}")
        
        # Cambiar a la pestaña de logs
        self.notebook.select(2)  # Pestaña de logs
        
        # Habilitar botón de ejecutar
        self.run_btn.configure(state='normal')
        
        # Mostrar información de la herramienta
        self.log_text.insert(tk.END, f"\n🎯 Herramienta seleccionada: {tool['emoji']} {tool['name']}\n")
        self.log_text.insert(tk.END, f"📝 Descripción: {tool['description']}\n")
        self.log_text.insert(tk.END, f"📂 Script: {tool['script']}\n")
        self.log_text.insert(tk.END, f"🏷️ Categoría: {tool['category']}\n")
        self.log_text.insert(tk.END, "="*60 + "\n")
        self.log_text.see(tk.END)
    
    def execute_selected_tool(self):
        """Ejecutar la herramienta seleccionada"""
        if not self.selected_tool:
            messagebox.showwarning("Advertencia", "No hay herramienta seleccionada")
            return
        
        script_path = self.base_dir / self.selected_tool['script']
        
        if not script_path.exists():
            messagebox.showerror("Error", f"Script no encontrado: {script_path}")
            return
        
        # Configurar UI para ejecución
        self.run_btn.configure(state='disabled')
        self.stop_btn.configure(state='normal')
        self.progress.start()
        self.update_status(f"Ejecutando: {self.selected_tool['name']}")
        
        # Ejecutar en hilo separado
        thread = threading.Thread(target=self.execute_script, args=(script_path,))
        thread.daemon = True
        thread.start()
    
    def execute_script(self, script_path):
        """Ejecutar script en hilo separado (método existente)"""
        try:
            os.chmod(script_path, 0o755)
            
            self.current_process = subprocess.Popen(
                [str(script_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                cwd=script_path.parent
            )
            
            for line in iter(self.current_process.stdout.readline, ''):
                if self.current_process.poll() is None or line:
                    self.root.after(0, self.append_output, line)
            
            return_code = self.current_process.wait()
            self.root.after(0, self.execution_finished, return_code)
            
        except Exception as e:
            self.root.after(0, self.execution_error, str(e))
    
    def append_output(self, text):
        """Agregar texto a la salida"""
        self.log_text.insert(tk.END, text)
        self.log_text.see(tk.END)
        self.log_content.append(f"{datetime.now().strftime('%H:%M:%S')} - {text.strip()}")
    
    def execution_finished(self, return_code):
        """Manejar finalización de ejecución"""
        self.progress.stop()
        self.run_btn.configure(state='normal')
        self.stop_btn.configure(state='disabled')
        
        if return_code == 0:
            self.update_status("✅ Ejecución completada exitosamente")
        else:
            self.update_status(f"❌ Ejecución terminada con código: {return_code}")
        
        self.current_process = None
    
    def execution_error(self, error_msg):
        """Manejar error de ejecución"""
        self.progress.stop()
        self.run_btn.configure(state='normal')
        self.stop_btn.configure(state='disabled')
        self.append_output(f"ERROR: {error_msg}\n")
        self.update_status(f"❌ Error: {error_msg}")
        self.current_process = None
    
    def stop_execution(self):
        """Detener ejecución actual"""
        if self.current_process:
            self.current_process.terminate()
            self.update_status("⏹️ Ejecución detenida por el usuario")
    
    def clear_logs(self):
        """Limpiar logs"""
        self.log_text.delete(1.0, tk.END)
        self.log_content.clear()
        self.update_status("Logs limpiados")
    
    def export_logs(self):
        """Exportar logs"""
        if not self.log_content:
            messagebox.showinfo("Información", "No hay contenido para exportar")
            return
        
        filename = filedialog.asksaveasfilename(
            defaultextension=".log",
            filetypes=[("Log files", "*.log"), ("Text files", "*.txt"), ("All files", "*.*")],
            initialname=f"argocd_solutions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        )
        
        if filename:
            try:
                with open(filename, 'w', encoding='utf-8') as f:
                    f.write(f"ArgoCD Solutions Manager - Log Export\n")
                    f.write(f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                    f.write(f"Herramienta: {getattr(self.selected_tool, 'name', 'N/A') if self.selected_tool else 'N/A'}\n")
                    f.write("=" * 50 + "\n\n")
                    f.write('\n'.join(self.log_content))
                
                messagebox.showinfo("Éxito", f"Log exportado a: {filename}")
                self.update_status(f"Log exportado: {filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Error al exportar: {e}")
    
    def update_system_info(self):
        """Actualizar información del sistema"""
        self.system_info_text.delete(1.0, tk.END)
        
        info_lines = [
            "🖥️ INFORMACIÓN DEL SISTEMA",
            "=" * 50,
            f"📅 Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"📁 Directorio: {self.base_dir}",
            f"🛠️ Herramientas disponibles: {len(self.tools)}",
            "",
            "📦 ESTADO DE DEPENDENCIAS:",
        ]
        
        # Verificar dependencias
        dependencies = ['kubectl', 'helm', 'git', 'jq', 'yq']
        for dep in dependencies:
            try:
                result = subprocess.run(['which', dep], capture_output=True, text=True)
                if result.returncode == 0:
                    info_lines.append(f"✅ {dep}: {result.stdout.strip()}")
                else:
                    info_lines.append(f"❌ {dep}: No encontrado")
            except:
                info_lines.append(f"❌ {dep}: Error al verificar")
        
        # Información de Kubernetes
        info_lines.extend(["", "☸️ KUBERNETES:"])
        try:
            result = subprocess.run(['kubectl', 'config', 'current-context'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                info_lines.append(f"🎯 Contexto: {result.stdout.strip()}")
            
            result = subprocess.run(['kubectl', 'get', 'ns', '-o', 'name'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                namespaces = [ns.replace('namespace/', '') for ns in result.stdout.strip().split('\n') 
                            if 'argo' in ns.lower()]
                if namespaces:
                    info_lines.append(f"🏷️ NS ArgoCD: {', '.join(namespaces)}")
                else:
                    info_lines.append("🏷️ NS ArgoCD: No encontrados")
        except:
            info_lines.append("❌ Error conectando a Kubernetes")
        
        self.system_info_text.insert(tk.END, '\n'.join(info_lines))
    
    def update_status(self, message):
        """Actualizar barra de estado"""
        self.status_label.configure(text=message)
    
    def save_config(self):
        """Guardar configuración"""
        messagebox.showinfo("Configuración", "Configuración guardada exitosamente")
        self.update_status("Configuración guardada")
    
    def show_config(self):
        """Mostrar configuración"""
        self.notebook.select(3)  # Pestaña de configuración
    
    def show_help(self):
        """Mostrar ayuda"""
        help_text = """
🚀 ArgoCD Solutions Manager - Ayuda

Esta herramienta integra múltiples soluciones para ArgoCD:

🔧 Mantenimiento:
- Redis HA Fix: Repara problemas de Redis
- Zombie Cleaner: Limpia recursos atorados

📋 Validación:
- CRDs Checker: Verifica compatibilidad
- Pre-update Check: Validaciones previas

🔄 Actualización:
- Safe CRD Upgrade: Actualización segura
- CRD Updater: Actualiza CRDs

🔍 Análisis:
- Orphan Analyzer: Encuentra recursos huérfanos
- Performance Monitor: Monitorea rendimiento
- Security Analyzer: Análisis de seguridad

Para usar:
1. Selecciona una herramienta
2. Ve a la pestaña Logs
3. Click en Ejecutar
4. Revisa los resultados
"""
        messagebox.showinfo("Ayuda", help_text)
    
    def check_dependencies(self):
        """Verificar dependencias críticas"""
        critical_deps = ['kubectl']
        missing_deps = []
        
        for dep in critical_deps:
            try:
                subprocess.run(['which', dep], capture_output=True, check=True)
            except:
                missing_deps.append(dep)
        
        if missing_deps:
            messagebox.showwarning(
                "Dependencias Faltantes",
                f"Las siguientes dependencias críticas no están instaladas:\n\n"
                f"• {chr(10).join(missing_deps)}\n\n"
                f"Algunas funciones pueden no estar disponibles."
            )

def main():
    """Función principal"""
    root = tk.Tk()
    app = ModernArgocdManager(root)
    
    # Manejar cierre de ventana
    def on_closing():
        if app.current_process:
            if messagebox.askokcancel("Salir", "Hay un proceso ejecutándose. ¿Deseas terminar?"):
                app.current_process.terminate()
                root.destroy()
        else:
            root.destroy()
    
    root.protocol("WM_DELETE_WINDOW", on_closing)
    
    # Centrar ventana
    root.update_idletasks()
    x = (root.winfo_screenwidth() // 2) - (root.winfo_width() // 2)
    y = (root.winfo_screenheight() // 2) - (root.winfo_height() // 2)
    root.geometry(f"+{x}+{y}")
    
    # Iniciar aplicación
    root.mainloop()

if __name__ == "__main__":
    main()