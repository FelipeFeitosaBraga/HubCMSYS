# -*- coding: utf-8 -*-
"""
HUB CMSYS - Preparar PC de cliente novo
=======================================
Janela com botoes. Cada botao abre uma janela preta (CMD) e executa um .bat
da pasta "scripts". O programa em si NAO faz as tarefas: ele so organiza
os botoes, pede permissao de administrador e registra o resultado em log.
Assim, para mudar o que um botao faz, basta editar o .bat (sem recompilar).

Como rodar durante o desenvolvimento:   python hub.py
Como gerar o .exe:                      build.bat
"""

# ---------------------------------------------------------------- IMPORTS
import ctypes                      # chamar funcoes do Windows (checar admin)
import os                          # variaveis de ambiente e caminhos
import platform                    # nome/versao do sistema operacional
import subprocess                  # abrir o CMD para rodar os .bat
import sys                         # saber se estamos rodando como .exe
import threading                   # rodar o .bat sem travar a janela
import tkinter as tk               # biblioteca de janelas (ja vem no Python)
from datetime import datetime      # data/hora para o log
from pathlib import Path           # manipular caminhos de forma segura
from tkinter import messagebox, ttk

# ------------------------------------------------------------ CAMINHOS
# BASE_DIR = pasta onde o programa esta.
#  - Como .exe (PyInstaller): a pasta do proprio HubCMSYS.exe
#  - Como script .py: a pasta do hub.py
# E nela que o programa procura o cmsys.zip (modo offline).
if getattr(sys, "frozen", False):
    BASE_DIR = Path(sys.executable).resolve().parent
else:
    BASE_DIR = Path(__file__).resolve().parent


def achar_pasta_scripts() -> Path:
    """Devolve a pasta com os .bat.

    Ordem de busca:
      1) pasta 'scripts' ao lado do programa (permite editar os .bat);
      2) pasta 'scripts' embutida dentro do .exe (build.bat usa --add-data).
    """
    candidatas = [BASE_DIR / "scripts"]
    if getattr(sys, "frozen", False):
        # _MEIPASS = pasta temporaria onde o PyInstaller descompacta o .exe
        candidatas.append(Path(getattr(sys, "_MEIPASS", BASE_DIR)) / "scripts")
    for pasta in candidatas:
        if pasta.is_dir():
            return pasta
    return candidatas[0]


PASTA_SCRIPTS = achar_pasta_scripts()

# Pasta de logs: C:\ProgramData\CMSYS_Preparacao (mesma do script antigo).
PASTA_LOG = Path(os.environ.get("ProgramData", "C:\\ProgramData")) / "CMSYS_Preparacao"

# --------------------------------------------------------------- BOTOES
# Cada item: (texto do botao, explicacao exibida ao lado, arquivo .bat)
# Para criar um botao novo: coloque o .bat em "scripts" e adicione aqui.
BOTOES = [
    ("1  Rede como Privada",
     "Troca as conexoes de rede 'Publicas' para 'Privadas'. Redes de dominio nao sao alteradas.",
     "1_rede_privada.bat"),
    ("2  Firewall + portas",
     "Desativa o Firewall do Windows e cria as regras TS (porta 3389) e SQL (porta 1433), "
     "entrada e saida, sem duplicar.",
     "2_firewall.bat"),
    ("3  Baixar estrutura CMSYS",
     "Baixa o cmsys.zip (~1,7 GB), confere se esta inteiro, extrai e copia pastas + arquivos "
     "para C:\\cmsys (ou o disco escolhido). Se a internet cair, continua de onde parou.",
     "3_baixar_estrutura.bat"),
    ("4  Windows Update",
     "Procura, baixa e instala as atualizacoes do Windows. Se pedir reinicio, pergunta se "
     "pode reiniciar.",
     "4_windows_update.bat"),
    ("EXECUTAR TUDO  (1 + 2 + 3 + 4)",
     "Roda as quatro etapas em sequencia e mostra um resumo no final.",
     "0_tudo.bat"),
]


# ------------------------------------------------------------ ADMINISTRADOR
def eh_admin() -> bool:
    """True se o programa ja esta rodando como administrador."""
    if os.name != "nt":          # fora do Windows (so para testar o codigo)
        return True
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def reabrir_como_admin() -> None:
    """Pede ao Windows para abrir este mesmo programa como administrador.

    O verbo 'runas' faz aparecer a janelinha de confirmacao do UAC.
    Os .bat herdam essa permissao, entao nao precisam pedir de novo.
    """
    if getattr(sys, "frozen", False):          # rodando como .exe
        executavel = sys.executable
        argumentos = " ".join(f'"{a}"' for a in sys.argv[1:])
    else:                                      # rodando como python hub.py
        executavel = sys.executable
        argumentos = " ".join(f'"{a}"' for a in sys.argv)
    ctypes.windll.shell32.ShellExecuteW(None, "runas", executavel, argumentos, None, 1)


# ---------------------------------------------------------------------- LOG
def registrar_log(texto: str) -> None:
    """Acrescenta uma linha com data/hora no log do dia."""
    try:
        PASTA_LOG.mkdir(parents=True, exist_ok=True)
        arquivo = PASTA_LOG / f"hub_{datetime.now():%Y%m%d}.txt"
        with open(arquivo, "a", encoding="utf-8") as f:
            f.write(f"{datetime.now():%H:%M:%S}  {texto}\n")
    except Exception:
        pass  # log e opcional: nunca deve travar o programa


# ------------------------------------------------------------------ JANELA
class Hub:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.ocupado = False            # True enquanto um .bat esta rodando
        self.botoes_ui = []             # guarda os botoes para (des)habilitar

        root.title("Hub CMSYS - Preparar PC (cliente novo)")
        root.resizable(False, False)

        # ---- cabecalho com dados da maquina ----
        cab = ttk.Frame(root, padding=(14, 12, 14, 4))
        cab.pack(fill="x")
        ttk.Label(cab, text="PREPARAR PC - CLIENTE NOVO (CMSYS)",
                  font=("Segoe UI", 14, "bold")).pack(anchor="w")
        info = (f"Computador: {os.environ.get('COMPUTERNAME', '?')}   |   "
                f"Usuario: {os.environ.get('USERNAME', '?')}   |   {platform.platform()}")
        ttk.Label(cab, text=info, foreground="#555").pack(anchor="w")

        # ---- uma linha por botao: [botao] explicacao ----
        corpo = ttk.Frame(root, padding=(14, 8))
        corpo.pack(fill="both")
        for i, (titulo, descricao, arquivo) in enumerate(BOTOES):
            b = ttk.Button(corpo, text=titulo, width=32,
                           command=lambda t=titulo, a=arquivo: self.executar(t, a))
            b.grid(row=i, column=0, sticky="w", pady=5, ipady=6)
            ttk.Label(corpo, text=descricao, wraplength=420, justify="left").grid(
                row=i, column=1, sticky="w", padx=(12, 0))
            self.botoes_ui.append(b)

        # ---- rodape: status + atalhos ----
        rodape = ttk.Frame(root, padding=(14, 4, 14, 12))
        rodape.pack(fill="x")
        self.status = tk.StringVar(value="Pronto. Escolha uma etapa.")
        ttk.Label(rodape, textvariable=self.status).pack(side="left")
        ttk.Button(rodape, text="Sair", command=root.destroy).pack(side="right")
        ttk.Button(rodape, text="Abrir pasta de logs", command=self.abrir_logs).pack(
            side="right", padx=6)

    # ---- liga/desliga os botoes (evita rodar duas etapas ao mesmo tempo) ----
    def definir_ocupado(self, ocupado: bool, mensagem: str) -> None:
        self.ocupado = ocupado
        for b in self.botoes_ui:
            b.config(state="disabled" if ocupado else "normal")
        self.status.set(mensagem)

    def executar(self, titulo: str, arquivo: str) -> None:
        """Chamado ao clicar num botao."""
        bat = PASTA_SCRIPTS / arquivo
        if not bat.is_file():
            messagebox.showerror("Arquivo nao encontrado",
                                 f"Nao achei o script:\n{bat}\n\n"
                                 "Confira se a pasta 'scripts' esta ao lado do programa.")
            return
        if self.ocupado:
            return
        self.definir_ocupado(True, f"Executando: {titulo} ... (acompanhe na janela preta)")
        # Thread = "linha de execucao" paralela, para a janela nao congelar.
        threading.Thread(target=self._rodar, args=(titulo, bat), daemon=True).start()

    def _rodar(self, titulo: str, bat: Path) -> None:
        """Roda o .bat numa janela de CMD propria e espera ele terminar."""
        # HUB_DIR avisa o .bat onde esta o programa (para achar o cmsys.zip).
        ambiente = os.environ.copy()
        ambiente["HUB_DIR"] = str(BASE_DIR)
        codigo, erro = None, ""
        try:
            processo = subprocess.Popen(
                ["cmd.exe", "/c", str(bat)],            # /c = executa e fecha
                cwd=str(bat.parent),
                env=ambiente,
                # CREATE_NEW_CONSOLE = abre uma janela de CMD visivel
                creationflags=getattr(subprocess, "CREATE_NEW_CONSOLE", 0),
            )
            codigo = processo.wait()                    # espera o .bat terminar
        except Exception as e:                          # ex.: cmd.exe inexistente
            erro = str(e)
        registrar_log(f"{titulo} -> codigo {codigo} {erro}".strip())
        # Voltar para a thread da janela (tkinter nao aceita mexer na UI daqui).
        self.root.after(0, self._terminou, titulo, codigo, erro)

    def _terminou(self, titulo: str, codigo, erro: str) -> None:
        if erro:
            self.definir_ocupado(False, f"Erro ao executar '{titulo}'")
            messagebox.showerror("Erro", erro)
        elif codigo == 0:
            self.definir_ocupado(False, f"Concluido com sucesso: {titulo}")
        else:
            self.definir_ocupado(False, f"Terminou com avisos/erros (codigo {codigo}): {titulo}")

    def abrir_logs(self) -> None:
        PASTA_LOG.mkdir(parents=True, exist_ok=True)
        os.startfile(str(PASTA_LOG))  # abre no Explorer (so existe no Windows)


# ------------------------------------------------------------------- MAIN
def main() -> None:
    # Sem admin os .bat nao conseguem mexer em rede/firewall: reabre elevado.
    if not eh_admin():
        reabrir_como_admin()
        return
    try:  # deixa a janela nitida em telas com escala (125%, 150%...)
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        pass
    root = tk.Tk()
    Hub(root)
    root.mainloop()


if __name__ == "__main__":
    main()
