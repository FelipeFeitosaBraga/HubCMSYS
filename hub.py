# -*- coding: utf-8 -*-
"""
HUB CMSYS - Preparar PC de cliente novo
=======================================
Janela com botoes. Cada botao abre uma janela preta (CMD) e executa um .bat
da pasta "scripts". O programa em si NAO faz as tarefas: ele organiza os
botoes, pede permissao de administrador e registra o resultado em log.
Assim, para mudar o que um botao faz, basta editar o .bat (sem recompilar).

A unica parte feita aqui no Python e a que precisa de janelas: perguntar
se ja quer restaurar o banco e ajudar a baixar o .bak no portal da Azure
(botao 5). Isso fica na classe JanelaPortal e na funcao obter_backup.

Como rodar durante o desenvolvimento:   python hub.py
Como gerar o .exe:                      build.bat
"""

# ---------------------------------------------------------------- IMPORTS
import ctypes                      # chamar funcoes do Windows (checar admin)
import os                          # variaveis de ambiente e caminhos
import platform                    # nome/versao do sistema operacional
import re                          # ler as linhas "set" do config_hub.bat
import shutil                      # mover o .bak para a pasta do SQL
import subprocess                  # abrir o CMD para rodar os .bat
import sys                         # saber se estamos rodando como .exe
import threading                   # rodar o .bat sem travar a janela
import time                        # hora de inicio para achar o download novo
import tkinter as tk               # biblioteca de janelas (ja vem no Python)
import uuid                        # identificador da pasta Downloads
import webbrowser                  # abrir o portal no navegador padrao
import zipfile                     # caso o backup venha dentro de um .zip
from datetime import datetime      # data/hora para o log
from pathlib import Path           # manipular caminhos de forma segura
from tkinter import filedialog, messagebox, ttk

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
    ("4  Instalar SQL Server + SSMS",
     "Instala o SQL Server 2025 Express e o SSMS com as configuracoes do manual (precisa de "
     "internet). No final pergunta se voce ja quer restaurar o banco do cliente.",
     "4_instalar_sql.bat"),
    ("5  Restaurar banco do CMSYS",
     "Pergunta se o .bak ja foi baixado. Se nao, abre o portal da Azure com o login pronto para "
     "copiar, espera o download e move o .bak para cmsys\\Suporte\\SQLSERVER2025. Depois "
     "restaura (cmsys ou cmsys_fN), liga TCP/IP e Pipes e reinicia o servico.",
     "5_restaurar_banco.bat"),
    ("6  Instalar CMSYS na estacao",
     "ReportViewer 2010, Crystal Runtime 2008, CMSYS Relatorios (remove as versoes antigas "
     "antes), CMSYS Boleto em C:\\CmsysBoleto e os componentes do CMSYS. Pula o que ja esta "
     "instalado e so troca arquivo por versao mais nova.",
     "6_instalar_cmsys.bat"),
    ("7  Windows Update",
     "Procura, baixa e instala as atualizacoes do Windows. Fica por ultimo porque pode pedir "
     "reinicio.",
     "7_windows_update.bat"),
    ("8  Migrar arquivos (servidor antigo)",
     "So para troca de servidor: copia pela rede (robocopy) os XML de cupom, XML e PDF das "
     "notas de cada CNPJ, as fotos e os logos do cmsys antigo para o novo. Nao apaga nada e "
     "pode rodar de novo. Nao faz parte do Executar tudo.",
     "8_migrar_arquivos.bat"),
    ("EXECUTAR TUDO  (1 a 7)",
     "Roda as sete etapas em sequencia. Depois do SQL pergunta se quer restaurar o banco. "
     "Mostra um resumo no final.",
     "0_tudo.bat"),
]

# Valores padrao do portal (o config_hub.bat tem prioridade sobre estes).
PORTAL_URL_PADRAO = "https://www.azuresistemas.com.br/restorebackup/RestoreBackupLocal"
PORTAL_USUARIO_PADRAO = "Cmsys"
PORTAL_SENHA_PADRAO = "old*{EMPRESA}/0"     # mesma regra da extensao Auto Login 2.0
MESES = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]


# ------------------------------------------------------------ CONFIGURACAO
def ler_config() -> dict:
    """Le as linhas  set "NOME=valor"  do config_hub.bat.

    Assim o tecnico muda a URL do portal, o usuario e a regra da senha num
    so lugar (o mesmo arquivo da senha do sa), sem recompilar o Hub.
    """
    cfg = {}
    try:
        texto = (PASTA_SCRIPTS / "config_hub.bat").read_text(encoding="latin-1")
    except OSError:
        return cfg
    for m in re.finditer(r'^\s*set\s+"([^=]+)=(.*)"\s*$', texto, re.M | re.I):
        cfg[m.group(1).strip().upper()] = m.group(2)
    return cfg


def achar_pasta_sql(cfg: dict):
    """Mesma busca do _achar_pasta_sql.bat: X:\\cmsys\\Suporte\\SQLSERVER2025."""
    rel = cfg.get("PASTA_SQL_REL", r"cmsys\Suporte\SQLSERVER2025")
    letras = list("CDEFGHIJKLMNOPQRSTUVWXYZ")
    try:  # disco gravado pelo botao 3 vai na frente
        primeiro = (PASTA_LOG / "disco_cmsys.txt").read_text().strip()[:1].upper()
        if primeiro:
            letras.insert(0, primeiro)
    except OSError:
        pass
    for letra in letras:
        pasta = Path(f"{letra}:\\") / rel
        if pasta.is_dir():
            return pasta
    return None


def pasta_downloads() -> Path:
    """Pasta Downloads do usuario (mesmo se ele mudou de lugar)."""
    try:
        from ctypes import wintypes

        class GUID(ctypes.Structure):
            _fields_ = [("Data1", wintypes.DWORD), ("Data2", wintypes.WORD),
                        ("Data3", wintypes.WORD), ("Data4", ctypes.c_ubyte * 8)]

        u = uuid.UUID("374DE290-123F-4565-9168-E04ABB1A4BE3")   # FOLDERID_Downloads
        g = GUID(u.fields[0], u.fields[1], u.fields[2],
                 (ctypes.c_ubyte * 8).from_buffer_copy(u.bytes[8:]))
        caminho = ctypes.c_wchar_p()
        if ctypes.windll.shell32.SHGetKnownFolderPath(ctypes.byref(g), 0, None,
                                                      ctypes.byref(caminho)) == 0:
            resultado = caminho.value
            ctypes.windll.ole32.CoTaskMemFree(caminho)
            return Path(resultado)
    except Exception:
        pass
    return Path.home() / "Downloads"


def zip_tem_bak(arquivo: Path) -> bool:
    """True se o .zip esta completo e tem um .bak dentro."""
    try:
        with zipfile.ZipFile(arquivo) as z:
            return any(n.lower().endswith(".bak") for n in z.namelist())
    except Exception:
        return False   # zip ainda baixando ou corrompido


def guardar_bak(arquivo: Path, pasta_sql: Path) -> Path:
    """Coloca o backup em cmsys\\Suporte\\SQLSERVER2025 e devolve o caminho final.

    - .bak: MOVE para a pasta (se ja houver um com o mesmo nome, substitui).
    - .zip: extrai o .bak de dentro (o maior, se houver mais de um).
    Tenta algumas vezes porque o antivirus as vezes segura o arquivo logo
    depois do download.
    """
    for tentativa in range(10):
        try:
            if arquivo.suffix.lower() == ".zip":
                with zipfile.ZipFile(arquivo) as z:
                    baks = [i for i in z.infolist() if i.filename.lower().endswith(".bak")]
                    item = max(baks, key=lambda i: i.file_size)
                    destino = pasta_sql / Path(item.filename).name
                    with z.open(item) as origem, open(destino, "wb") as saida:
                        shutil.copyfileobj(origem, saida, 1024 * 1024)
                return destino
            if arquivo.resolve().parent == pasta_sql.resolve():
                return arquivo                     # ja esta no lugar certo
            destino = pasta_sql / arquivo.name
            if destino.exists():
                destino.unlink()                   # sobrescreve, nao duplica
            # COPIA e depois apaga o original (em vez de "mover"): assim o
            # arquivo novo herda as permissoes da pasta do SQL. Movido, ele
            # levaria as permissoes da pasta Downloads e o servico do SQL
            # nao conseguiria ler (Acesso negado).
            shutil.copyfile(str(arquivo), str(destino))
            arquivo.unlink()
            return destino
        except PermissionError:
            if tentativa == 9:
                raise
            time.sleep(2)
    return arquivo


# --------------------------------------------- JANELA DA MIGRACAO (botao 8)
class JanelaMigracao:
    """Pergunta origem, destino e o que copiar do servidor antigo.

    Devolve um dicionario com as variaveis MIG_* para o 8_migrar_arquivos.bat
    (ou None se o tecnico cancelar).
    """

    ITENS = [("MIG_CUPOM", "XML de cupom  (Aplicativo\\CFe\\RETORNO\\XML)"),
             ("MIG_NOTAS", "Notas: XML e PDF de cada CNPJ  (NFe\\<CNPJ>\\XML e PDF)"),
             ("MIG_FOTOS", "Fotos  (Fotos, se houver)"),
             ("MIG_LOGOS", "Logos  (Aplicativo\\Logo.jpg/png e Logo.gif; sem eles, os nativos)")]

    def __init__(self, root: tk.Tk, destino_padrao: str) -> None:
        self.resultado = None
        w = self.win = tk.Toplevel(root)
        w.title("Migrar arquivos do servidor antigo")
        w.resizable(False, False)
        w.transient(root)
        w.protocol("WM_DELETE_WINDOW", w.destroy)

        f = ttk.Frame(w, padding=14)
        f.pack(fill="both")
        ttk.Label(f, justify="left", text=(
            "Origem: a pasta cmsys do servidor ANTIGO, pelo caminho de rede\n"
            "(ex.: \\\\SERVIDOR\\c$\\cmsys). Letra de unidade mapeada (Z:) nao funciona aqui.\n"
            "Destino: a pasta cmsys desta maquina.")).grid(row=0, column=0, columnspan=3,
                                                           sticky="w", pady=(0, 10))

        self.var_origem = tk.StringVar(value="\\\\SERVIDOR\\c$\\cmsys")
        self.var_destino = tk.StringVar(value=destino_padrao)
        self.var_usuario = tk.StringVar()
        self.var_senha = tk.StringVar()
        linhas = [("Origem", self.var_origem, True), ("Destino", self.var_destino, True),
                  ("Usuario (opcional)", self.var_usuario, False),
                  ("Senha (opcional)", self.var_senha, False)]
        for i, (rotulo, var, procurar) in enumerate(linhas, start=1):
            ttk.Label(f, text=rotulo).grid(row=i, column=0, sticky="w", pady=3)
            e = ttk.Entry(f, textvariable=var, width=46, show="*" if "Senha" in rotulo else "")
            e.grid(row=i, column=1, sticky="w", padx=8)
            if procurar:
                ttk.Button(f, text="Procurar...",
                           command=lambda v=var: self.procurar(v)).grid(row=i, column=2)
        ttk.Label(f, foreground="#555", text="Usuario/senha: so se o servidor antigo pedir login "
                  "(ex.: SERVIDOR\\Administrador).").grid(row=5, column=0, columnspan=3,
                                                         sticky="w", pady=(0, 8))

        self.marcados = {}
        for i, (chave, texto) in enumerate(self.ITENS, start=6):
            var = tk.BooleanVar(value=True)
            ttk.Checkbutton(f, text=texto, variable=var).grid(row=i, column=0, columnspan=3,
                                                              sticky="w")
            self.marcados[chave] = var
        self.var_simular = tk.BooleanVar(value=False)
        ttk.Checkbutton(f, text="So simular (mostra o que copiaria, sem copiar nada)",
                        variable=self.var_simular).grid(row=10, column=0, columnspan=3,
                                                        sticky="w", pady=(8, 0))

        rodape = ttk.Frame(f)
        rodape.grid(row=11, column=0, columnspan=3, sticky="e", pady=(12, 0))
        ttk.Button(rodape, text="Copiar", command=self.confirmar).pack(side="left")
        ttk.Button(rodape, text="Cancelar", command=w.destroy).pack(side="left", padx=(8, 0))
        w.grab_set()

    def mostrar(self):
        self.win.wait_window()
        return self.resultado

    def procurar(self, var: tk.StringVar) -> None:
        pasta = filedialog.askdirectory(parent=self.win, title="Escolha a pasta cmsys")
        if pasta:
            var.set(pasta.replace("/", "\\"))

    def confirmar(self) -> None:
        origem = self.var_origem.get().strip().rstrip("\\")
        destino = self.var_destino.get().strip().rstrip("\\")
        if not origem or not destino:
            messagebox.showwarning("Migrar", "Informe a origem e o destino.", parent=self.win)
            return
        if origem.lower() == destino.lower():
            messagebox.showwarning("Migrar", "Origem e destino sao a mesma pasta.", parent=self.win)
            return
        if re.match(r"^[A-Za-z]:", origem) and not messagebox.askyesno(
                "Migrar", "A origem esta numa letra de unidade. Se for unidade de rede mapeada, "
                "ela nao aparece para o Hub (administrador).\n\nUse \\\\SERVIDOR\\... "
                "Continuar mesmo assim?", parent=self.win):
            return
        if not any(v.get() for v in self.marcados.values()):
            messagebox.showwarning("Migrar", "Marque pelo menos um item.", parent=self.win)
            return
        self.resultado = {"MIG_ORIGEM": origem, "MIG_DESTINO": destino,
                          "MIG_USUARIO": self.var_usuario.get().strip(),
                          "MIG_SENHA": self.var_senha.get(),
                          "MIG_SIMULAR": "1" if self.var_simular.get() else "0"}
        for chave, var in self.marcados.items():
            self.resultado[chave] = "1" if var.get() else "0"
        self.win.destroy()


# ------------------------------------------------ JANELA DO PORTAL (download)
class JanelaPortal:
    """Janela que ajuda a baixar o .bak no portal da Azure.

    1) o tecnico digita o codigo da empresa;
    2) o Hub monta usuario e senha (regra do config_hub.bat) com botoes Copiar;
    3) "Abrir portal" abre o site no navegador padrao para o login;
    4) depois do login, "Abrir pagina do backup" abre a mesma URL de novo;
    5) a cada 2 segundos o Hub olha a pasta Downloads; quando aparece um .bak
       (ou .zip com .bak) novo e o tamanho para de mudar, a janela fecha
       sozinha e devolve o arquivo.
    """

    def __init__(self, root: tk.Tk, cfg: dict) -> None:
        self.url = cfg.get("PORTAL_URL") or PORTAL_URL_PADRAO
        self.modelo_senha = cfg.get("PORTAL_SENHA") or PORTAL_SENHA_PADRAO
        self.downloads = pasta_downloads()
        self.inicio = time.time() - 5       # so vale arquivo baixado DEPOIS de abrir
        self.tamanhos = {}                  # arquivo -> tamanho na ultima olhada
        self.resultado = None

        w = self.win = tk.Toplevel(root)
        w.title("Baixar o backup do cliente")
        w.resizable(False, False)
        w.transient(root)
        w.protocol("WM_DELETE_WINDOW", self.cancelar)

        f = ttk.Frame(w, padding=14)
        f.pack(fill="both")
        passos = ("1) Digite o codigo da empresa do cliente.\n"
                  "2) Clique em 'Abrir portal' e faca o login (use os botoes Copiar).\n"
                  "3) Depois de logar, clique em 'Abrir pagina do backup' e baixe o backup.\n"
                  "4) Quando o download terminar, o Hub pega o arquivo sozinho.")
        ttk.Label(f, text=passos, justify="left").grid(row=0, column=0, columnspan=3,
                                                       sticky="w", pady=(0, 10))

        self.var_empresa = tk.StringVar()
        self.var_usuario = tk.StringVar(value=cfg.get("PORTAL_USUARIO") or PORTAL_USUARIO_PADRAO)
        self.var_senha = tk.StringVar()
        self.var_empresa.trace_add("write", lambda *_: self.atualizar_senha())
        for linha, (rotulo, var) in enumerate([("Empresa", self.var_empresa),
                                               ("Usuario", self.var_usuario),
                                               ("Senha", self.var_senha)], start=1):
            ttk.Label(f, text=rotulo).grid(row=linha, column=0, sticky="w", pady=3)
            e = ttk.Entry(f, textvariable=var, width=32)
            e.grid(row=linha, column=1, sticky="w", padx=8)
            if linha == 1:
                e.focus_set()
            ttk.Button(f, text="Copiar", command=lambda v=var: self.copiar(v.get())).grid(
                row=linha, column=2, sticky="w")

        botoes = ttk.Frame(f)
        botoes.grid(row=4, column=0, columnspan=3, sticky="w", pady=(10, 4))
        ttk.Button(botoes, text="Abrir portal (login)", command=self.abrir).pack(side="left")
        ttk.Button(botoes, text="Abrir pagina do backup", command=self.abrir).pack(
            side="left", padx=8)

        self.status = tk.StringVar(value=f"Aguardando o .bak em: {self.downloads}")
        ttk.Label(f, textvariable=self.status, foreground="#555", wraplength=460,
                  justify="left").grid(row=5, column=0, columnspan=3, sticky="w", pady=(6, 10))

        rodape = ttk.Frame(f)
        rodape.grid(row=6, column=0, columnspan=3, sticky="e")
        ttk.Button(rodape, text="Escolher arquivo...", command=self.escolher).pack(side="left")
        ttk.Button(rodape, text="Cancelar", command=self.cancelar).pack(side="left", padx=(8, 0))

        w.grab_set()                       # trava a janela principal enquanto esta aberta
        w.after(2000, self.verificar)

    def mostrar(self):
        """Espera a janela fechar e devolve o arquivo baixado (ou None)."""
        self.win.wait_window()
        return self.resultado

    def atualizar_senha(self) -> None:
        empresa = self.var_empresa.get().strip()
        agora = datetime.now()
        # {EMPRESA} ou {empresa} (como na extensao); {MES} e {ANO} opcionais.
        senha = re.sub(r"\{empresa\}", lambda _: empresa, self.modelo_senha, flags=re.I)
        senha = (senha.replace("{MES}", MESES[agora.month - 1])
                 .replace("{ANO}", f"{agora:%y}"))
        self.var_senha.set(senha if empresa else "")

    def copiar(self, texto: str) -> None:
        self.win.clipboard_clear()
        self.win.clipboard_append(texto)
        self.status.set(f"Copiado: {texto if texto != self.var_senha.get() else 'senha'}")

    def abrir(self) -> None:
        if not self.var_empresa.get().strip():
            messagebox.showwarning("Empresa", "Digite o codigo da empresa primeiro.", parent=self.win)
            return
        webbrowser.open(self.url)
        registrar_log(f"Portal aberto para a empresa {self.var_empresa.get().strip()}")

    def escolher(self) -> None:
        arq = filedialog.askopenfilename(parent=self.win, initialdir=str(self.downloads),
                                         title="Escolha o backup do cliente",
                                         filetypes=[("Backup do SQL", "*.bak *.zip")])
        if arq:
            self.resultado = Path(arq)
            self.win.destroy()

    def cancelar(self) -> None:
        self.resultado = None
        self.win.destroy()

    def verificar(self) -> None:
        if self.resultado is not None or not self.win.winfo_exists():
            return
        achado = self.procurar_download()
        if achado:
            self.resultado = achado
            self.win.destroy()
            return
        self.win.after(2000, self.verificar)

    def procurar_download(self):
        """Devolve um .bak/.zip novo e completo da pasta Downloads, ou None."""
        try:
            arquivos = [a for a in self.downloads.iterdir() if a.is_file()]
        except OSError:
            return None
        nomes = {a.name.lower() for a in arquivos}
        for a in arquivos:
            sufixo = a.suffix.lower()
            if sufixo not in (".bak", ".zip"):
                continue
            st = a.stat()
            if max(st.st_mtime, st.st_ctime) < self.inicio or st.st_size == 0:
                continue                                   # arquivo antigo ou vazio
            if (a.name + ".part").lower() in nomes:
                continue                                   # Firefox ainda baixando
            if sufixo == ".zip" and not zip_tem_bak(a):
                continue
            anterior = self.tamanhos.get(a)
            self.tamanhos[a] = st.st_size
            if anterior == st.st_size:
                return a                                   # tamanho parou de mudar
            self.status.set(f"Download encontrado: {a.name}. Conferindo se terminou...")
        return None


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
                           command=lambda t=titulo, a=arquivo: self.clicar(t, a))
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

    # ------------------------------------------------------------------
    #  FLUXO DE UM CLIQUE
    #  O trabalho roda numa thread separada (a janela nao congela). Quando
    #  a thread precisa perguntar algo ao tecnico, usa self.na_ui(...), que
    #  abre a pergunta na thread da janela e espera a resposta.
    # ------------------------------------------------------------------
    def clicar(self, titulo: str, arquivo: str) -> None:
        """Chamado ao clicar num botao."""
        if self.ocupado:
            return
        if not (PASTA_SCRIPTS / arquivo).is_file():
            messagebox.showerror("Arquivo nao encontrado",
                                 f"Nao achei o script:\n{PASTA_SCRIPTS / arquivo}\n\n"
                                 "Confira se a pasta 'scripts' esta ao lado do programa.")
            return
        self.definir_ocupado(True, f"Executando: {titulo} ... (acompanhe na janela preta)")
        threading.Thread(target=self._fluxo, args=(titulo, arquivo), daemon=True).start()

    def _fluxo(self, titulo: str, arquivo: str) -> None:
        try:
            if arquivo == "0_tudo.bat":
                mensagem = self.fluxo_tudo()
            elif arquivo == "4_instalar_sql.bat":
                r4, r5 = self.fluxo_sql(auto=False)
                mensagem = f"SQL + SSMS: {self.texto(r4)}   |   Restaurar banco: {self.texto(r5)}"
            elif arquivo == "8_migrar_arquivos.bat":
                mensagem = f"Migrar arquivos: {self.texto(self.fluxo_migrar())}"
            elif arquivo == "5_restaurar_banco.bat":
                mensagem = f"Restaurar banco: {self.texto(self.fluxo_restaurar(auto=False))}"
            else:
                mensagem = f"{titulo}: {self.texto(self.rodar_bat(titulo, arquivo))}"
        except Exception as e:                          # nunca deixa o Hub travado
            registrar_log(f"ERRO no fluxo {titulo}: {e}")
            mensagem = f"Erro em '{titulo}'"
            erro = str(e)                               # 'e' some depois do except
            self.na_ui(lambda: messagebox.showerror("Erro", erro, parent=self.root))
        self.root.after(0, self.definir_ocupado, False, mensagem)

    @staticmethod
    def texto(resultado) -> str:
        """Codigo do .bat -> texto curto para a barra de status e o resumo."""
        if resultado == 0:
            return "OK"
        if isinstance(resultado, str):
            return resultado                             # "pulado", "nao pedido"...
        return f"falhou (codigo {resultado})"

    def na_ui(self, funcao):
        """Roda 'funcao' na thread da janela e devolve o resultado."""
        if threading.current_thread() is threading.main_thread():
            return funcao()
        pronto, caixa = threading.Event(), {}

        def chamar():
            try:
                caixa["valor"] = funcao()
            except Exception as e:
                caixa["erro"] = e
            finally:
                pronto.set()

        self.root.after(0, chamar)
        pronto.wait()
        if "erro" in caixa:
            raise caixa["erro"]
        return caixa.get("valor")

    def rodar_bat(self, titulo: str, arquivo: str, args=(), env_extra=None):
        """Roda um .bat numa janela de CMD propria, espera e devolve o codigo."""
        bat = PASTA_SCRIPTS / arquivo
        self.na_ui(lambda: self.status.set(f"Executando: {titulo} ... (acompanhe na janela preta)"))
        ambiente = os.environ.copy()
        ambiente["HUB_DIR"] = str(BASE_DIR)              # onde esta o programa (cmsys.zip)
        ambiente.update(env_extra or {})
        try:
            processo = subprocess.Popen(
                ["cmd.exe", "/c", str(bat), *args],      # /c = executa e fecha
                cwd=str(bat.parent),
                env=ambiente,
                creationflags=getattr(subprocess, "CREATE_NEW_CONSOLE", 0),
            )
            codigo = processo.wait()
        except Exception as e:
            registrar_log(f"{titulo} -> erro {e}")
            return f"erro ({e})"
        registrar_log(f"{titulo} -> codigo {codigo}")
        return codigo

    # ---------------------------------------------- BOTOES 4 e 5 (SQL)
    def fluxo_sql(self, auto: bool):
        """Instala o SQL e, se o tecnico quiser, ja restaura o banco."""
        args = ["/auto"] if auto else []
        r4 = self.rodar_bat("4  Instalar SQL Server + SSMS", "4_instalar_sql.bat", args)
        if r4 != 0:
            return r4, "pulado"
        quer = self.na_ui(lambda: messagebox.askyesno(
            "Restaurar o banco?",
            "O SQL Server e o SSMS estao instalados.\n\n"
            "Voce quer ja restaurar o banco do cliente agora?\n\n"
            "Sim: seguimos para o backup (.bak).\n"
            "Nao: fica so o SQL instalado (use o botao 5 depois).",
            parent=self.root))
        if not quer:
            registrar_log("Restaurar banco: tecnico escolheu nao restaurar agora")
            return r4, "nao pedido"
        return r4, self.fluxo_restaurar(auto)

    def fluxo_restaurar(self, auto: bool):
        """Consegue o .bak (ja baixado ou pelo portal) e roda o botao 5."""
        bak = self.obter_backup()
        if bak is None:
            return "cancelado"
        args = ["/auto"] if auto else []
        return self.rodar_bat("5  Restaurar banco do CMSYS", "5_restaurar_banco.bat", args,
                              {"BAK_ESCOLHIDO": str(bak)})

    def obter_backup(self):
        """Pergunta se o .bak ja foi baixado e devolve o caminho dele ja em
        cmsys\\Suporte\\SQLSERVER2025 (ou None se o tecnico cancelar)."""
        cfg = ler_config()
        pasta_sql = achar_pasta_sql(cfg)
        if pasta_sql is None:
            self.na_ui(lambda: messagebox.showerror(
                "Pasta do SQL", "Nao achei cmsys\\Suporte\\SQLSERVER2025 em nenhum disco.\n"
                "Rode o botao 3 (Baixar estrutura) primeiro.", parent=self.root))
            return None

        ja_baixou = self.na_ui(lambda: messagebox.askyesnocancel(
            "Backup do cliente",
            "Voce ja baixou o .bak deste cliente?\n\n"
            "Sim: eu procuro o arquivo baixado.\n"
            "Nao: abro o portal da Azure para baixar agora.",
            parent=self.root))
        if ja_baixou is None:
            return None
        if ja_baixou:
            arquivo = self.na_ui(lambda: self.escolher_bak_existente(pasta_sql))
        else:
            self.na_ui(lambda: self.status.set("Aguardando o download do backup no portal..."))
            arquivo = self.na_ui(lambda: JanelaPortal(self.root, cfg).mostrar())
        if not arquivo:
            return None

        self.na_ui(lambda: self.status.set(f"Movendo {Path(arquivo).name} para {pasta_sql} ..."))
        destino = guardar_bak(Path(arquivo), pasta_sql)
        registrar_log(f"Backup pronto para restaurar: {destino}")
        return destino

    def escolher_bak_existente(self, pasta_sql: Path):
        """Sugere o .bak mais recente (Downloads ou pasta do SQL); se nao for
        esse, abre a janela para escolher."""
        candidatos = []
        for pasta in (pasta_downloads(), pasta_sql):
            try:
                candidatos += [a for a in pasta.glob("*.bak") if a.is_file()]
            except OSError:
                pass
        if candidatos:
            mais_novo = max(candidatos, key=lambda a: a.stat().st_mtime)
            data = datetime.fromtimestamp(mais_novo.stat().st_mtime)
            usar = messagebox.askyesnocancel(
                "Usar este backup?",
                f"{mais_novo.name}\n{mais_novo.parent}\n{data:%d/%m/%Y %H:%M}\n\n"
                "Sim: usar este arquivo.\nNao: escolher outro.", parent=self.root)
            if usar is None:
                return None
            if usar:
                return mais_novo
        arq = filedialog.askopenfilename(parent=self.root, initialdir=str(pasta_downloads()),
                                         title="Escolha o backup do cliente",
                                         filetypes=[("Backup do SQL", "*.bak *.zip")])
        return Path(arq) if arq else None

    # ------------------------------------------------- BOTAO 8 (migracao)
    def fluxo_migrar(self):
        """Pergunta origem/destino e roda o robocopy (8_migrar_arquivos.bat)."""
        pasta_sql = achar_pasta_sql(ler_config())
        # Destino padrao: a pasta cmsys desta maquina (disco achado pelo botao 3).
        destino = str(pasta_sql.parents[1]) if pasta_sql else "C:\\cmsys"
        opcoes = self.na_ui(lambda: JanelaMigracao(self.root, destino).mostrar())
        if not opcoes:
            return "cancelado"
        registrar_log(f"Migrar: {opcoes['MIG_ORIGEM']} -> {opcoes['MIG_DESTINO']}")
        return self.rodar_bat("8  Migrar arquivos", "8_migrar_arquivos.bat", env_extra=opcoes)

    # ---------------------------------------------------- EXECUTAR TUDO
    def fluxo_tudo(self) -> str:
        """1 a 7 em sequencia (cada .bat com /auto) e resumo no final."""
        r = {}
        r[1] = self.rodar_bat("1  Rede como Privada", "1_rede_privada.bat", ["/auto"])
        r[2] = self.rodar_bat("2  Firewall + portas", "2_firewall.bat", ["/auto"])
        r[3] = self.rodar_bat("3  Baixar estrutura CMSYS", "3_baixar_estrutura.bat", ["/auto"])
        if r[3] == 0:                                    # 4, 5 e 6 dependem da estrutura
            r[4], r[5] = self.fluxo_sql(auto=True)
            r[6] = self.rodar_bat("6  Instalar CMSYS na estacao", "6_instalar_cmsys.bat", ["/auto"])
        else:
            r[4] = r[5] = r[6] = "pulado"
        r[7] = self.rodar_bat("7  Windows Update", "7_windows_update.bat", ["/auto"])

        nomes = {1: "Rede privada", 2: "Firewall e portas", 3: "Estrutura CMSYS",
                 4: "SQL Server + SSMS", 5: "Restaurar banco", 6: "Instalar CMSYS",
                 7: "Windows Update"}
        resumo = "\n".join(f"{n}) {nomes[n]}: {self.texto(r[n])}" for n in range(1, 8))
        registrar_log("EXECUTAR TUDO\n" + resumo)
        self.na_ui(lambda: messagebox.showinfo("Resumo - Executar tudo", resumo, parent=self.root))
        tudo_ok = all(r[n] == 0 or r[n] == "nao pedido" for n in r)
        return "Executar tudo: concluido" if tudo_ok else "Executar tudo: terminou com pendencias (veja o resumo)"

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
