#!/usr/bin/env python3
"""Diagrama da UC do sonar2 agrupado por modo, a partir da extracao do Yosys.

Le o JSON do fsm-diagrama (make figura-fsm MOD=sonar2_uc SAIDAS=1), que traz
os estados, as saidas de Moore e as transicoes extraidas do RTL pelo Yosys, e
gera um .dot com os estados separados em comuns, modo 0 e modo 1 (secao 1.2-B
do roteiro). Uso, na raiz do projeto:

    python3 scripts/fsm_por_modo.py docs/figuras/fsm_sonar2_uc.json \
        docs/figuras/uc_sonar2_modos

O que nao vem do Yosys esta marcado abaixo e foi conferido no RTL e no
sonar2_tb: a saida fim_posicao (OU de dois estados, que o avaliador de saidas
nao resolve). A FSM de modo (1 bit, que o extrator ignora) fica fora deste
diagrama: esta no README e, no relatorio, em figura propria.
"""

import json
import subprocess
import sys

# Grupos de estados por modo de funcionamento
MODO0 = {"muda_posicao", "final_posicao"}    # localizacao
MODO1 = {"final_atencao"}                    # atencao

# Saidas que o avaliador do fsm-diagrama deixa indeterminadas ("?")
SAIDAS_DO_RTL = {
    "final_posicao": ["fim_posicao"],
    "final_atencao": ["fim_posicao"],
}

# Notas para leitura (nao sao saidas)
NOTAS = {"final_atencao": "servo parado"}

AZUL, LARANJA, AMBAR = "#1d4ed8", "#c2410c", "#b45309"


def nome_estado(nome):
    """O extrator junta constantes de mesmo valor ("LOCALIZACAO / inicial");
    os estados da FSM de sequencia sao os nomes em minusculas."""
    partes = [p.strip() for p in nome.split("/")]
    minusculas = [p for p in partes if p.islower()]
    return minusculas[0] if minusculas else partes[0]


def condicao(padrao, entradas):
    """Traduz o padrao do Yosys (o ultimo caractere e a primeira entrada) numa
    expressao legivel. ligar = 1 fica implicito (ligar = 0 leva a inicial)."""
    termos = []
    for i, entrada in enumerate(entradas):
        bit = padrao[len(padrao) - 1 - i]
        if bit == "-" or entrada == "ligar":
            continue
        if entrada == "db_modo":
            termos.append("Matual = " + ("ATENCAO" if bit == "1" else "LOCALIZACAO"))
        else:
            termos.append(entrada if bit == "1" else "!" + entrada)
    return " &\\n".join(termos)


def main(arquivo_json, saida):
    with open(arquivo_json) as f:
        fsm = json.load(f)["fsms"][0]
    entradas = fsm["inputs"]
    estados = {e["id"]: e for e in fsm["states"]}
    nomes = {i: nome_estado(e["name"]) for i, e in estados.items()}

    # Agrupa as transicoes por par de estados; descarta as de ligar = 0
    arestas = {}
    for t in fsm["transitions"]:
        ligar = t["pattern"][len(t["pattern"]) - 1 - entradas.index("ligar")]
        if ligar == "0":
            continue
        arestas.setdefault((t["from"], t["to"]), []).append(condicao(t["pattern"], entradas))

    def no(i):
        nome = nomes[i]
        codigo = "%X" % int(estados[i]["code"], 2)
        ativas = [s for s, v in estados[i]["outputs"].items()
                  if v == "1" and s not in ("db_estado", "db_modo")]
        ativas += SAIDAS_DO_RTL.get(nome, [])
        extra = "".join('<br/><font color="gray30">%s</font>' % s for s in ativas)
        if nome in NOTAS:
            extra += '<br/><font point-size="11">%s</font>' % NOTAS[nome]
        estilo = ""
        if nome == "proximo_char":
            extra += "<br/><b>bifurcação</b>"
            estilo = ', fillcolor="#fef3c7", color="%s"' % AMBAR
        return '    %s [label=<%s (%s)%s>%s];' % (nome, nome, codigo, extra, estilo)

    linhas = [
        "// Gerado por scripts/fsm_por_modo.py a partir de " + arquivo_json,
        "// (estados e transicoes extraidos do RTL pelo Yosys). Nao edite a mao.",
        "digraph sonar2_uc {",
        '  graph [fontname="Helvetica", fontsize=14, newrank=true, nodesep=0.25, ranksep=0.3];',
        '  node  [fontname="Helvetica", fontsize=13, shape=box, style="rounded,filled", fillcolor="white", margin="0.08,0.03"];',
        '  edge  [fontname="Helvetica", fontsize=12, arrowsize=0.8];',
        "",
        "  subgraph cluster_comum {",
        '    label=<<b>Estados comuns aos dois modos</b>&nbsp;(ciclo da exp5)>;',
        '    style="rounded,dashed"; color="gray45"; fontsize=14;',
        "    reset_e [shape=point, width=0.08];",
    ]
    for i in sorted(estados):
        if nomes[i] not in MODO0 | MODO1:
            linhas.append(no(i))
    linhas += [
        "  }",
        "  subgraph cluster_modo0 {",
        '    label=<<b>Modo 0: localização</b>>; labelloc=b; style="rounded,filled";',
        '    fillcolor="#dbeafe"; color="%s"; fontcolor="%s"; fontsize=14;' % (AZUL, AZUL),
    ]
    linhas += [no(i) for i in sorted(estados) if nomes[i] in MODO0]
    linhas += [
        "  }",
        "  subgraph cluster_modo1 {",
        '    label=<<b>Modo 1: atenção</b>>; labelloc=b; style="rounded,filled";',
        '    fillcolor="#ffedd5"; color="%s"; fontcolor="%s"; fontsize=14;' % (LARANJA, LARANJA),
    ]
    linhas += [no(i) for i in sorted(estados) if nomes[i] in MODO1]
    linhas += ["  }", "", "  reset_e -> %s [label=\"reset\"];" % nomes[fsm["reset"]]]
    # Duas colunas, como um ASM: medida a esquerda, envio a direita
    linhas += ["  { rank=same; espera_medida; envia_char; }",
               "  { rank=same; timeout_medida; espera_tx; }"]

    # Ordem de declaracao das arestas segue o ciclo, para o desenho ficar estavel
    ordem = ["inicial", "preparacao", "espera", "dispara_medida", "espera_medida",
             "timeout_medida", "envia_char", "espera_tx", "proximo_char",
             "muda_posicao", "final_posicao", "final_atencao"]
    chave = {n: k for k, n in enumerate(ordem)}
    for (de, para), conds in sorted(arestas.items(),
                                    key=lambda a: (chave.get(nomes[a[0][0]], 99),
                                                   chave.get(nomes[a[0][1]], 99))):
        rotulo = "\\nOU ".join(c for c in conds if c) or ""
        if not rotulo and de == fsm["reset"] and para != de:
            rotulo = "ligar"            # saida do estado inicial: so depende de ligar
        n_de, n_para = nomes[de], nomes[para]
        atrib = ['label="%s"' % rotulo] if rotulo else []
        cor = AZUL if (n_para in MODO0 or n_de in MODO0) else LARANJA if (n_para in MODO1 or n_de in MODO1) else None
        if cor:
            atrib += ['color="%s"' % cor, 'fontcolor="%s"' % cor]
        if n_de == "proximo_char" and n_para in MODO0 | MODO1:
            atrib.append("penwidth=1.6")
        if n_para == "espera" and n_de in MODO0 | MODO1:
            atrib.append("constraint=false")
        if n_de == n_para and n_de in ("espera", "espera_medida"):
            atrib += ["tailport=w", "headport=w"]   # laco a esquerda: a direita saem outras arestas
        linhas.append("  %s -> %s [%s];" % (n_de, n_para, ", ".join(atrib)))

    linhas += [
        "}",
    ]

    with open(saida + ".dot", "w") as f:
        f.write("\n".join(linhas) + "\n")
    for formato in ("svg", "pdf"):
        subprocess.run(["dot", "-T" + formato, saida + ".dot", "-o", saida + "." + formato], check=True)
    print("%s.dot/.svg/.pdf: %d estados, %d transicoes (com ligar = 1)"
          % (saida, len(estados), sum(len(c) for c in arestas.values())))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("uso: fsm_por_modo.py <fsm.json> <saida_sem_extensao>")
    main(sys.argv[1], sys.argv[2])
