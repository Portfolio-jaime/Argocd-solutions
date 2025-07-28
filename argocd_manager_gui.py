#!/usr/bin/env python3
"""
ArgoCD Solutions Manager - GUI Principal
Herramienta con interfaz gráfica que integra todas las soluciones de ArgoCD
Autor: Jaime Andrés Henao
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog
import subprocess
import threading
import os
import sys
from datetime import datetime
import json
from pathlib import Path

class ArgocdSolutionsManager:
    def __init__(self, root):
        self.root = root
        self.root.title("ArgoCD Solutions Manager")
        self.root.geometry("1200x800")
        self.root.configure(bg='#f0f0f0')
        
        # Configurar el directorio base
        self.base_dir = Path(__file__).parent
        
        # Variables de estado
        self.current_process = None
        self.log_content = []
        
        # Configurar estilo
        self.setup_styles()
        
        # Crear la interfaz
        self.create_main_interface()
        
        # Verificar dependencias al inicio
        self.check_dependencies()
    
    def setup_styles(self):
        """Configurar estilos para la interfaz"""
        style = ttk.Style()
        style.theme_use('clam')
        
        # Configurar colores personalizados
        style.configure('Title.TLabel', font=('Arial', 16, 'bold'), foreground='#2E86AB')
        style.configure('Subtitle.TLabel', font=('Arial', 12, 'bold'), foreground='#A23B72')
        style.configure('Action.TButton', font=('Arial', 10, 'bold'))
        style.configure('Success.TLabel', foreground='#28A745')
        style.configure('Error.TLabel', foreground='#DC3545')
        style.configure('Warning.TLabel', foreground='#FFC107')
    
    def create_main_interface(self):
        """Crear la interfaz principal"""
        # Frame principal
        self.main_frame = ttk.Frame(self.root, padding="10")
        self.main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configurar grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        self.main_frame.columnconfigure(1, weight=1)
        self.main_frame.rowconfigure(2, weight=1)
        
        # Título principal
        title_label = ttk.Label(self.main_frame, text="🚀 ArgoCD Solutions Manager", 
                               style='Title.TLabel')
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 20))
        
        # Panel izquierdo - Menú de herramientas
        self.create_tools_panel()
        
        # Panel central - Área de trabajo
        self.create_work_area()
        
        # Panel derecho - Información y logs
        self.create_info_panel()
        
        # Barra de estado
        self.create_status_bar()
    
    def create_tools_panel(self):
        """Crear panel de herramientas"""
        tools_frame = ttk.LabelFrame(self.main_frame, text="🛠️ Herramientas ArgoCD", 
                                    padding="10")
        tools_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=(0, 10))
        
        # Definir las herramientas disponibles
        self.tools = [
            {
                'name': '🔧 Redis HA Fix',
                'description': 'Diagnostica y repara problemas de Redis HA',
                'script': 'Check-Redis-ha/redis-ha-fix.sh',
                'category': 'Mantenimiento',
                'color': '#FF6B6B'
            },
            {
                'name': '🧹 Zombie Cleaner',
                'description': 'Limpia AppProjects con finalizers atorados',
                'script': 'Check-argocd/argocd-zombie-cleaner.sh',
                'category': 'Limpieza',
                'color': '#4ECDC4'
            },
            {
                'name': '📋 CRDs Checker',
                'description': 'Verifica compatibilidad de CRDs',
                'script': 'Check_CRDs-K8s/check_crds-argocd.sh',
                'category': 'Validación',
                'color': '#45B7D1'
            },
            {
                'name': '🔄 Safe CRD Upgrade',
                'description': 'Actualización segura de CRDs con TUI',
                'script': 'Check_crds_compatibilitie/safe_crd_upgrade_tui.sh',
                'category': 'Actualización',
                'color': '#F9CA24'
            },
            {
                'name': '🔍 ArgoCD Inspector',
                'description': 'Inspecciona configuración de ArgoCD',
                'script': 'Check_resources_and_healthcheck/inspect_argocd.sh',
                'category': 'Diagnóstico',
                'color': '#6C5CE7'
            },
            {
                'name': '✅ Pre-update Check',
                'description': 'Validaciones antes de actualizar',
                'script': 'Pre-update_check/pre-validation.sh',
                'category': 'Validación',
                'color': '#A29BFE'
            },
            {
                'name': '🔧 CRD Updater',
                'description': 'Actualiza CRDs de ArgoCD',
                'script': 'Update_argocd_crds/argocd-crd-updater.sh',
                'category': 'Actualización',
                'color': '#FD79A8'
            },
            {
                'name': '🕵️ Orphan Analyzer',
                'description': 'Analiza recursos huérfanos en el cluster',
                'script': 'Orphan_resources_analyzer/orphan_analyzer.sh',
                'category': 'Análisis',
                'color': '#E17055'
            },
            {
                'name': '📊 Performance Monitor',
                'description': 'Monitorea rendimiento de ArgoCD en tiempo real',
                'script': 'Performance_monitor/performance_monitor.sh',
                'category': 'Monitoreo',
                'color': '#00B894'
            },
            {
                'name': '🔐 Security Analyzer',
                'description': 'Análisis comprehensivo de seguridad',
                'script': 'Security_analyzer/security_analyzer.sh',
                'category': 'Seguridad',
                'color': '#E84393'
            }
        ]
        
        # Crear botones para cada herramienta
        for i, tool in enumerate(self.tools):
            btn = ttk.Button(tools_frame, text=tool['name'], 
                           command=lambda t=tool: self.run_tool(t),
                           style='Action.TButton')
            btn.grid(row=i, column=0, sticky=(tk.W, tk.E), pady=2)
            
            # Tooltip con descripción
            self.create_tooltip(btn, f"{tool['description']}\nCategoría: {tool['category']}")
        
        tools_frame.columnconfigure(0, weight=1)
    
    def create_work_area(self):
        """Crear área de trabajo central"""
        work_frame = ttk.LabelFrame(self.main_frame, text="💻 Área de Trabajo", 
                                   padding="10")
        work_frame.grid(row=1, column=1, sticky=(tk.W, tk.E, tk.N, tk.S), padx=(0, 10))
        work_frame.columnconfigure(0, weight=1)
        work_frame.rowconfigure(1, weight=1)
        
        # Área de información de la herramienta seleccionada
        self.tool_info_frame = ttk.Frame(work_frame)
        self.tool_info_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        self.tool_title = ttk.Label(self.tool_info_frame, text="Selecciona una herramienta", 
                                   style='Subtitle.TLabel')
        self.tool_title.grid(row=0, column=0, sticky=tk.W)
        
        self.tool_description = ttk.Label(self.tool_info_frame, 
                                         text="Elige una herramienta del panel izquierdo para comenzar",
                                         wraplength=400)
        self.tool_description.grid(row=1, column=0, sticky=tk.W, pady=(5, 0))
        
        # Área de salida de comandos
        self.output_text = scrolledtext.ScrolledText(work_frame, height=20, width=60)
        self.output_text.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Botones de control
        control_frame = ttk.Frame(work_frame)
        control_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.run_btn = ttk.Button(control_frame, text="▶️ Ejecutar", 
                                 command=self.execute_selected_tool, state='disabled')
        self.run_btn.grid(row=0, column=0, padx=(0, 5))
        
        self.stop_btn = ttk.Button(control_frame, text="⏹️ Detener", 
                                  command=self.stop_execution, state='disabled')
        self.stop_btn.grid(row=0, column=1, padx=(0, 5))
        
        self.clear_btn = ttk.Button(control_frame, text="🗑️ Limpiar", 
                                   command=self.clear_output)
        self.clear_btn.grid(row=0, column=2, padx=(0, 5))
        
        self.export_btn = ttk.Button(control_frame, text="💾 Exportar Log", 
                                    command=self.export_log)
        self.export_btn.grid(row=0, column=3)
    
    def create_info_panel(self):
        """Crear panel de información"""
        info_frame = ttk.LabelFrame(self.main_frame, text="ℹ️ Información del Sistema", 
                                   padding="10")
        info_frame.grid(row=1, column=2, sticky=(tk.W, tk.E, tk.N, tk.S))
        info_frame.columnconfigure(0, weight=1)
        
        # Información del sistema
        self.system_info_text = scrolledtext.ScrolledText(info_frame, height=10, width=30)
        self.system_info_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Botón para actualizar información
        refresh_btn = ttk.Button(info_frame, text="🔄 Actualizar Info", 
                                command=self.update_system_info)
        refresh_btn.grid(row=1, column=0, pady=(5, 0))
        
        # Mostrar información inicial
        self.update_system_info()
    
    def create_status_bar(self):
        """Crear barra de estado"""
        self.status_frame = ttk.Frame(self.main_frame)
        self.status_frame.grid(row=3, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.status_label = ttk.Label(self.status_frame, text="Listo")
        self.status_label.grid(row=0, column=0, sticky=tk.W)
        
        self.progress_bar = ttk.Progressbar(self.status_frame, mode='indeterminate')
        self.progress_bar.grid(row=0, column=1, sticky=(tk.W, tk.E), padx=(10, 0))
        
        self.status_frame.columnconfigure(1, weight=1)
    
    def create_tooltip(self, widget, text):
        """Crear tooltip para un widget"""
        def on_enter(event):
            tooltip = tk.Toplevel()
            tooltip.wm_overrideredirect(True)
            tooltip.wm_geometry(f"+{event.x_root+10}+{event.y_root+10}")
            label = tk.Label(tooltip, text=text, background="yellow", 
                           relief="solid", borderwidth=1, font=("Arial", 9))
            label.pack()
            widget.tooltip = tooltip
        
        def on_leave(event):
            if hasattr(widget, 'tooltip'):
                widget.tooltip.destroy()
                del widget.tooltip
        
        widget.bind("<Enter>", on_enter)
        widget.bind("<Leave>", on_leave)
    
    def run_tool(self, tool):
        """Configurar herramienta seleccionada"""
        self.selected_tool = tool
        self.tool_title.configure(text=tool['name'])
        self.tool_description.configure(text=f"{tool['description']}\n\nScript: {tool['script']}")
        self.run_btn.configure(state='normal')
        self.update_status(f"Herramienta seleccionada: {tool['name']}")
    
    def execute_selected_tool(self):
        """Ejecutar la herramienta seleccionada"""
        if not hasattr(self, 'selected_tool'):
            messagebox.showwarning("Advertencia", "No hay herramienta seleccionada")
            return
        
        script_path = self.base_dir / self.selected_tool['script']
        
        if not script_path.exists():
            messagebox.showerror("Error", f"Script no encontrado: {script_path}")
            return
        
        # Configurar UI para ejecución
        self.run_btn.configure(state='disabled')
        self.stop_btn.configure(state='normal')
        self.progress_bar.start()
        self.update_status(f"Ejecutando: {self.selected_tool['name']}")
        
        # Ejecutar en hilo separado
        thread = threading.Thread(target=self.execute_script, args=(script_path,))
        thread.daemon = True
        thread.start()
    
    def execute_script(self, script_path):
        """Ejecutar script en hilo separado"""
        try:
            # Hacer el script ejecutable
            os.chmod(script_path, 0o755)
            
            # Ejecutar el script
            self.current_process = subprocess.Popen(
                [str(script_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                cwd=script_path.parent
            )
            
            # Leer salida en tiempo real
            for line in iter(self.current_process.stdout.readline, ''):
                if self.current_process.poll() is None or line:
                    self.root.after(0, self.append_output, line)
            
            # Esperar a que termine
            return_code = self.current_process.wait()
            
            # Actualizar UI al finalizar
            self.root.after(0, self.execution_finished, return_code)
            
        except Exception as e:
            self.root.after(0, self.execution_error, str(e))
    
    def append_output(self, text):
        """Agregar texto a la salida"""
        self.output_text.insert(tk.END, text)
        self.output_text.see(tk.END)
        self.log_content.append(f"{datetime.now().strftime('%H:%M:%S')} - {text.strip()}")
    
    def execution_finished(self, return_code):
        """Manejar finalización de ejecución"""
        self.progress_bar.stop()
        self.run_btn.configure(state='normal')
        self.stop_btn.configure(state='disabled')
        
        if return_code == 0:
            self.update_status("✅ Ejecución completada exitosamente", 'success')
        else:
            self.update_status(f"❌ Ejecución terminada con código: {return_code}", 'error')
        
        self.current_process = None
    
    def execution_error(self, error_msg):
        """Manejar error de ejecución"""
        self.progress_bar.stop()
        self.run_btn.configure(state='normal')
        self.stop_btn.configure(state='disabled')
        self.append_output(f"ERROR: {error_msg}\n")
        self.update_status(f"❌ Error: {error_msg}", 'error')
        self.current_process = None
    
    def stop_execution(self):
        """Detener ejecución actual"""
        if self.current_process:
            self.current_process.terminate()
            self.update_status("⏹️ Ejecución detenida por el usuario", 'warning')
    
    def clear_output(self):
        """Limpiar área de salida"""
        self.output_text.delete(1.0, tk.END)
        self.log_content.clear()
        self.update_status("Salida limpiada")
    
    def export_log(self):
        """Exportar log a archivo"""
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
                    f.write(f"Herramienta: {getattr(self, 'selected_tool', {}).get('name', 'N/A')}\n")
                    f.write("=" * 50 + "\n\n")
                    f.write('\n'.join(self.log_content))
                
                messagebox.showinfo("Éxito", f"Log exportado a: {filename}")
                self.update_status(f"Log exportado: {filename}", 'success')
            except Exception as e:
                messagebox.showerror("Error", f"Error al exportar: {e}")
    
    def update_system_info(self):
        """Actualizar información del sistema"""
        self.system_info_text.delete(1.0, tk.END)
        
        info_lines = [
            "🖥️ INFORMACIÓN DEL SISTEMA",
            "=" * 30,
            f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Directorio: {self.base_dir}",
            "",
            "📦 DEPENDENCIAS:",
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
            # Contexto actual
            result = subprocess.run(['kubectl', 'config', 'current-context'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                info_lines.append(f"Contexto: {result.stdout.strip()}")
            
            # Namespaces con ArgoCD
            result = subprocess.run(['kubectl', 'get', 'ns', '-o', 'name'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                namespaces = [ns.replace('namespace/', '') for ns in result.stdout.strip().split('\n') 
                            if 'argo' in ns.lower()]
                if namespaces:
                    info_lines.append(f"NS ArgoCD: {', '.join(namespaces)}")
                else:
                    info_lines.append("NS ArgoCD: No encontrados")
        except:
            info_lines.append("❌ Error conectando a Kubernetes")
        
        # Mostrar información
        self.system_info_text.insert(tk.END, '\n'.join(info_lines))
    
    def update_status(self, message, status_type='info'):
        """Actualizar barra de estado"""
        self.status_label.configure(text=message)
        
        # Cambiar color según tipo
        if status_type == 'success':
            self.status_label.configure(style='Success.TLabel')
        elif status_type == 'error':
            self.status_label.configure(style='Error.TLabel')
        elif status_type == 'warning':
            self.status_label.configure(style='Warning.TLabel')
        else:
            self.status_label.configure(style='TLabel')
    
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
    app = ArgocdSolutionsManager(root)
    
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