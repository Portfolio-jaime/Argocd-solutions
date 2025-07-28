import subprocess
import json
import os
import datetime
import questionary
from rich.console import Console
from rich.table import Table

console = Console()
NAMESPACE = "argocd"
LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)
LOGFILE = os.path.join(LOG_DIR, f"zombie_cleaner_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

def get_zombie_projects():
    cmd = ["kubectl", "get", "appproject", "-n", NAMESPACE, "-o", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        console.print(f"[red]Error ejecutando kubectl:[/red] {result.stderr}")
        return []

    data = json.loads(result.stdout)
    zombies = []
    for item in data["items"]:
        if item.get("metadata", {}).get("deletionTimestamp") and \
           item.get("metadata", {}).get("finalizers"):
            zombies.append(item["metadata"]["name"])
    return zombies

def has_active_apps(project):
    cmd = ["kubectl", "get", "applications.argoproj.io", "-n", NAMESPACE,
           f"--selector=argocd.argoproj.io/project={project}", "-o", "name"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return bool(result.stdout.strip())

def remove_finalizer(project):
    patch_cmd = ["kubectl", "patch", "appproject", project, "-n", NAMESPACE,
                 "-p", '{"metadata":{"finalizers":[]}}', "--type=merge"]
    result = subprocess.run(patch_cmd, capture_output=True, text=True)
    if result.returncode == 0:
        with open(LOGFILE, "a") as f:
            f.write(f"{datetime.datetime.now()} - Removed finalizer from {project}\n")
        console.print(f"[green]✅ Finalizer eliminado de:[/green] {project}")
    else:
        console.print(f"[red]❌ Error eliminando finalizer de {project}:[/red] {result.stderr}")

def main():
    console.print("[bold cyan]\n🔍 Buscando AppProjects zombis en ArgoCD...[/bold cyan]")
    zombies = get_zombie_projects()

    if not zombies:
        console.print("[green]✅ No se encontraron AppProjects zombis.[/green]")
        return

    table = Table(title="AppProjects Zombis Detectados")
    table.add_column("#", style="cyan", justify="right")
    table.add_column("Nombre del Proyecto", style="bold")

    for idx, project in enumerate(zombies, 1):
        table.add_row(str(idx), project)
    console.print(table)

    for project in zombies:
        console.print(f"\n[blue]🧪 Verificando aplicaciones activas para:[/blue] {project}")
        if has_active_apps(project):
            console.print(f"[yellow]⚠️  {project} tiene aplicaciones activas. Saltando...[/yellow]")
            continue

        confirm = questionary.confirm(
            f"¿Eliminar finalizer de '{project}'?").ask()
        if confirm:
            remove_finalizer(project)
        else:
            console.print(f"[cyan]⏭️  Saltado por el usuario:[/cyan] {project}")

    console.print(f"\n[bold green]🏁 Limpieza completada.[/bold green] Log guardado en: {LOGFILE}")

if __name__ == "__main__":
    main()
