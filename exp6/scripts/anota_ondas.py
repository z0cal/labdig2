#!/usr/bin/env python3
"""Anotacoes TikZ sobre as figuras de ondas do sonar2_tb.

Le os PDFs gerados por `make figuras-sim` (docs/figuras/sim) e os instantes de
docs/figuras/sim/eventos_sonar2.txt, e escreve, para cada figura, um .tex com o
tikzpicture completo: o PDF da forma de onda e as anotacoes por cima.

A posicao de cada anotacao sai do proprio PDF: os rotulos da regua de tempo
dao a escala tempo -> x, e os nomes dos sinais, a altura de cada linha. As
coordenadas TikZ sao as do PDF em pontos (x para a direita, y para baixo),
com a figura escalada para \\linewidth. Uso, na raiz do projeto:

    python3 scripts/anota_ondas.py docs/figuras/sim

e, no LaTeX, \\input{figures/sim/<figura>} dentro de um ambiente figure.
"""

import re
import subprocess
import sys
from pathlib import Path

X_DIREITA = 506.2    # borda direita da area de ondas (write wave -width 7.5), medida em todas as figuras
UNIDADE = {"ns": 1.0, "us": 1e3, "ms": 1e6}


class Figura:
    def __init__(self, pdf, janela):
        self.pdf = pdf
        saida = subprocess.run(["pdftotext", "-bbox-layout", str(pdf), "-"],
                               capture_output=True, text=True, check=True).stdout
        m = re.search(r'<page width="([0-9.]+)" height="([0-9.]+)"', saida)
        assert m, "%s: pagina sem dimensoes" % pdf
        self.largura, self.altura = float(m.group(1)), float(m.group(2))
        palavras = [(float(a), float(b), float(c), float(d), t) for a, b, c, d, t in re.findall(
            r'<word xMin="([-0-9.]+)" yMin="([-0-9.]+)" xMax="([-0-9.]+)" yMax="([-0-9.]+)">([^<]*)</word>',
            saida)]
        # Regua: "<numero> <unidade>" na mesma altura; o rotulo fica centrado na marca
        regua = []
        for i, (x0, y0, x1, y1, t) in enumerate(palavras[:-1]):
            u = palavras[i + 1]
            if re.fullmatch(r"[0-9.]+", t) and u[4] in UNIDADE and abs(u[1] - y0) < 0.5:
                regua.append(((x0 + u[2]) / 2, float(t) * UNIDADE[u[4]], y0))
        if not regua:
            sys.exit("%s: regua de tempo sem rotulos" % pdf)
        if len(regua) >= 2:
            (xa, ta, _), (xb, tb, _) = regua[0], regua[-1]
        else:
            # um so rotulo: o fim da janela fica na borda direita da area de ondas
            (xa, ta, _), (xb, tb) = regua[0], (X_DIREITA, janela[1])
        self.escala = (xb - xa) / (tb - ta)
        self.x0, self.t0 = xa, ta
        self.y_regua = min(y for _, _, y in regua) - 4
        # Rodape do write wave ("Entity: ... Date: ..."): cortado no \includegraphics
        y_rodape = min(p[1] for p in palavras if p[4].startswith("Entity:"))
        self.corte = self.altura - y_rodape + 1
        # Nomes dos sinais: acima da regua, alinhados a direita na coluna da esquerda
        acima = [p for p in palavras if p[3] < self.y_regua]
        borda = max(p[2] for p in acima if p[0] < 60)
        self.linhas = {p[4]: (p[1] + p[3]) / 2 for p in acima if abs(p[2] - borda) < 1.0}

    def x(self, t_ns):
        return self.x0 + (t_ns - self.t0) * self.escala

    def y(self, sinal):
        if sinal not in self.linhas:
            sys.exit("%s: sinal %r nao esta na figura (%s)" % (self.pdf, sinal, ", ".join(self.linhas)))
        return self.linhas[sinal]


def fmt(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def tex(texto):
    texto = texto.replace("_", r"\_").replace("#", r"\#").replace("%", r"\%")
    return texto.replace("µ", r"$\mu$").replace("→", r"$\rightarrow$")


# --------------------------------------------------------------------------
# Tipos de anotacao. Tempos em ns; dx, dy em pt da figura.
# --------------------------------------------------------------------------
def seta(f, t, sinal, texto, dx, dy):
    """Seta do texto (deslocado de dx, dy) ate o sinal no instante t."""
    xa, ya = f.x(t), f.y(sinal)
    lado = "right" if dx >= 0 else "left"
    return r"\draw[sa] (%s,%s) node[an, %s] {%s} -- (%s,%s);" % (
        fmt(xa + dx), fmt(ya + dy), lado, tex(texto), fmt(xa), fmt(ya))


def cota(f, t1, t2, sinal, texto, dy=8, lado="below"):
    """Cota entre t1 e t2, logo abaixo (ou acima) da linha do sinal."""
    y = f.y(sinal) + dy
    return (r"\draw[cota] (%s,%s) -- node[an, %s] {%s} (%s,%s);" % (
        fmt(f.x(t1)), fmt(y), lado, tex(texto), fmt(f.x(t2)), fmt(y)))


def rotulo(f, t, sinal, texto, dy=0, ancora="center"):
    return r"\node[an, anchor=%s] at (%s,%s) {%s};" % (
        ancora, fmt(f.x(t)), fmt(f.y(sinal) + dy), tex(texto))


def marca(f, t, texto, sinal_texto, dy=-8, lado="right"):
    """Linha vertical tracejada em t, com o texto junto a um sinal."""
    xa = f.x(t)
    return (r"\draw[mk] (%s,0) -- (%s,%s);" % (fmt(xa), fmt(xa), fmt(f.y_regua)) + "\n  " +
            r"\node[an, %s] at (%s,%s) {%s};" % (lado, fmt(xa), fmt(f.y(sinal_texto) + dy), tex(texto)))


# --------------------------------------------------------------------------
# Anotacoes de cada figura (instantes de eventos_sonar2.txt)
# --------------------------------------------------------------------------
def anotacoes(nome, f, ev):
    e = lambda n: ev[(nome, n)]
    us = 1000
    if nome == "sim_sonar2_geral":
        return [
            seta(f, ev[("sim_sonar2_comando_a", "start_bit")], "entrada_serial", "CT4: 'a'", -6, -9),
            seta(f, ev[("sim_sonar2_comando_v", "start_bit")], "entrada_serial", "CT8: 'v'", 6, -9),
            cota(f, ev[("sim_sonar2_comando_a", "rx_pronto")], ev[("sim_sonar2_comando_v", "rx_pronto")],
                 "posicao", "modo atenção: posição parada em 3", dy=9),
            cota(f, ev[("sim_sonar2_timeout", "trigger")], ev[("sim_sonar2_timeout", "timeout")],
                 "saida_serial", "CT7: timeout sem echo (20 ms)", dy=9),
            seta(f, ev[("sim_sonar2_comando_durante_tx", "recebeu_atencao")], "modo", "CT10 a CT13", -6, -9),
            seta(f, ev[("sim_sonar2_religar", "ligar_0")], "ligar", "CT18: religar", -6, 8),
            seta(f, ev[("sim_sonar2_reset", "reset")], "reset", "CT19: reset", -6, -9),
        ]
    if nome == "sim_sonar2_ciclo":
        return [
            seta(f, e("trigger"), "trigger", "1 trigger, depois da espera de 200 µs (2 s na placa)", 14, -6),
            cota(f, e("echo_sobe"), e("echo_desce"), "echo", "2 echo de 17 cm (1 ms)", dy=-9, lado="above"),
            seta(f, e("echo_desce"), "medida", "3 medida = 017", -12, -7),
            cota(f, e("inicio_tx"), e("fim_posicao"), "saida_serial", "4 mensagem 040,017#", dy=10),
            seta(f, e("fim_posicao") - 20, "conta_posicao", "5 muda_posicao", -14, 9),
            seta(f, e("fim_posicao"), "posicao", "posição 1 → 2", -16, 9),
            seta(f, e("fim_posicao"), "fim_posicao", "6 fim_posicao", -14, 9),
        ]
    if nome in ("sim_sonar2_comando_a", "sim_sonar2_comando_v"):
        letra, hexa, sinal_cmd, de, para = (("a", "61H", "recebeu_atencao", "LOCALIZACAO", "ATENCAO")
                                            if nome.endswith("_a") else
                                            ("v", "76H", "recebeu_voltar", "ATENCAO", "LOCALIZACAO"))
        ts, tp = e("start_bit"), e("rx_pronto")
        return [
            seta(f, ts, "entrada_serial", "start bit", 10, 9),
            cota(f, ts, ts + 86800, "entrada_serial", "quadro 7E1 de '%s' (10 bits, 86,8 µs)" % letra, dy=10),
            seta(f, tp, "rx_pronto", "pronto: %s µs após o start bit" % fmt((tp - ts) / us).replace(".", ","), -12, -7),
            seta(f, tp + 20, "rx_dado", "'%s' (%s)" % (letra, hexa), -16, -7),
            seta(f, tp, sinal_cmd, "%s: 1 ciclo" % sinal_cmd, -12, -7),
            seta(f, tp + 20, "modo", "%s → %s" % (de, para), -12, -7),
        ] + ([seta(f, tp, "paridade_ok", "paridade_ok volta a 1 (o último quadro, 'v' do CT6, tinha paridade errada)", -12, -7)]
             if letra == "v" else []) + [
            rotulo(f, (ts + tp) / 2, "estado", "a UC de sequência continua em espera", dy=-9),
        ]
    if nome in ("sim_sonar2_bifurcacao_atencao", "sim_sonar2_bifurcacao_localizacao"):
        tfp = e("fim_posicao")
        atencao = nome.endswith("atencao")
        # proximo_char: rotulo a esquerda na atencao; na localizacao ele fica mais
        # a esquerda (antes de muda_posicao) e o rotulo vai para a direita
        a = [seta(f, tfp - 10 - (20 if not atencao else 0), "estado", "proximo_char (7): bifurcação",
                  -10 if atencao else 10, 14),
             seta(f, tfp + 10, "fim_posicao", "fim_posicao", 14, -7)]
        if atencao:
            a += [seta(f, tfp + 10, "estado", "final_atencao (A)", 14, 14),
                  rotulo(f, tfp - 50, "modo", "Matual = ATENCAO", dy=7, ancora="west"),
                  rotulo(f, tfp, "conta_posicao", "conta_posicao = 0: o servo não anda", dy=-8),
                  rotulo(f, tfp + 30, "posicao", "posição continua 3", dy=-8)]
        else:
            a += [seta(f, tfp - 10, "conta_posicao", "muda_posicao (8): conta_posicao", -10, -9),
                  seta(f, tfp + 10, "estado", "final_posicao (F)", 14, 14),
                  rotulo(f, tfp - 50, "modo", "Matual = LOCALIZACAO", dy=7, ancora="west"),
                  seta(f, tfp, "posicao", "posição 3 → 4", 14, -8)]
        return a
    if nome == "sim_sonar2_ignorados":
        q = [e("quadro%d" % i) for i in range(1, 5)]
        nomes = ["'A'", "'x'", "'V'", "'v' com paridade errada"]
        a = [rotulo(f, t + 43400, "entrada_serial", n, dy=-9) for t, n in zip(q, nomes)]
        a += [seta(f, q[3] + 82600, "paridade_ok", "paridade_ok = 0", -14, -7),
              rotulo(f, (q[0] + q[3]) / 2 + 40000, "recebeu_voltar", "nenhum recebeu_*: os quatro são ignorados", dy=-12),
              rotulo(f, (q[0] + q[3]) / 2 + 40000, "modo", "continua em ATENCAO", dy=6),
              seta(f, e("janela") + 210 * us, "estado", "medida em andamento", 10, -8)]
        return a
    if nome == "sim_sonar2_timeout":
        return [
            seta(f, e("trigger"), "trigger", "trigger sem echo", 12, -6),
            cota(f, e("trigger"), e("timeout"), "estado", "espera_medida: timeout de 20 ms (10 s na placa)", dy=9),
            seta(f, e("timeout"), "fim_timeout", "fim_timeout", -12, -6),
            seta(f, e("timeout") + 20, "limpa_sensor", "limpa_sensor", -12, -6),
            seta(f, e("timeout") + 60 * us, "saida_serial", "080,000#", -14, -7),
            rotulo(f, (e("trigger") + e("timeout")) / 2, "posicao", "posição 3 mantida (modo atenção)", dy=-8),
            seta(f, e("fim_posicao"), "fim_posicao", "fim_posicao", -12, -6),
        ]
    if nome == "sim_sonar2_comando_durante_tx":
        return [
            seta(f, e("trigger"), "trigger", "trigger", 12, -6),
            cota(f, e("inicio_tx"), e("fim_posicao"), "saida_serial", "mensagem 120,012#", dy=-10, lado="above"),
            seta(f, e("inicio_tx") + 43400, "entrada_serial", "'a' durante a transmissão", -12, 9),
            seta(f, e("recebeu_atencao"), "recebeu_atencao", "recebeu_atencao", -12, -6),
            seta(f, e("recebeu_atencao") + 20, "modo", "ATENCAO antes da bifurcação", 12, -7),
            rotulo(f, (e("trigger") + e("inicio_tx")) / 2, "posicao", "posição 5 mantida", dy=-8),
            seta(f, e("fim_posicao"), "fim_posicao", "fim do ciclo em final_atencao", -12, -6),
        ]
    if nome == "sim_sonar2_religar":
        return [
            seta(f, e("ligar_0"), "ligar", "ligar = 0", 12, 9),
            seta(f, e("ligar_0") + 40, "modo", "modo volta a LOCALIZACAO", 12, -7),
            seta(f, e("ligar_1"), "ligar", "ligar = 1", 12, 9),
            seta(f, e("ligar_1") + 40, "posicao", "preparacao: posição 0", 12, -7),
            seta(f, e("trigger"), "trigger", "1ª medida após 200 µs", -12, -7),
        ]
    if nome == "sim_sonar2_reset":
        return [
            seta(f, e("start_bit"), "entrada_serial", "'a'", 10, -7),
            seta(f, e("start_bit") + 82600, "modo", "ATENCAO", 10, -7),
            seta(f, e("reset"), "reset", "reset", 10, -7),
            seta(f, e("reset") + 40, "modo", "LOCALIZACAO", 10, 9),
            seta(f, e("reset") + 2100, "posicao", "posição 0", 12, -7),
            seta(f, e("trigger"), "trigger", "1ª medida após 200 µs", -12, -7),
        ]
    return []


def main(pasta):
    pasta = Path(pasta)
    ev = {}
    for linha in (pasta / "eventos_sonar2.txt").read_text().splitlines():
        partes = linha.split()
        if len(partes) >= 3:
            ev[(partes[0], partes[1])] = float(partes[2])
    janelas = {}
    for linha in (pasta / "eventos_sonar2.txt").read_text().splitlines():
        partes = linha.split()
        if len(partes) == 4 and partes[1] == "janela":
            janelas[partes[0]] = (float(partes[2]), float(partes[3]))
    for pdf in sorted(pasta.glob("sim_sonar2_*.pdf")):
        f = Figura(pdf, janelas[pdf.stem])
        nome = pdf.stem
        corpo = anotacoes(nome, f, ev)
        w = fmt(f.largura)
        saida = [
            "% Gerado por scripts/anota_ondas.py: forma de onda do ModelSim e anotacoes.",
            r"\begin{tikzpicture}[x=\linewidth/%s, y=-\linewidth/%s]" % (w, w),
            r"  \node[anchor=north west, inner sep=0] at (0,0)",
            r"    {\includegraphics[width=\linewidth, trim=0 %s 0 0, clip]{figures/sim/%s.pdf}};" % (fmt(f.corte), nome),
        ]
        saida += ["  " + c for c in corpo]
        saida.append(r"\end{tikzpicture}")
        (pasta / (nome + ".tex")).write_text("\n".join(saida) + "\n")
        print("%s: %d anotacoes, %d sinais, %.4f pt/us" % (nome, len(corpo), len(f.linhas), f.escala * 1000))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "docs/figuras/sim")
