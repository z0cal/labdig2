//-----------------------------Laboratorio Digital--------------------------------------
// Arquivo: sonar_processing_2026.pde
// Projeto: Experiencia 5 - Sistema de Sonar
//--------------------------------------------------------------------------------------
// Descricao:
//            sketch processing: interface para radar com sensor ultrassônico
// 
//            baseado em código disponível no site:
//            http://howtomechatronics.com/projects/arduino-radar/
//
//--------------------------------------------------------------------------------------
// Revisoes:
//     Data        Versao  Autor             Descricao
//     28/10/2015  1.0     Edson Midorikawa  adaptacao inicial do sketch
//     21/10/2019  2.0     Edson Midorikawa  configuracao da interface serial
//     08/10/2021  3.0     Edson Midorikawa  adaptado para MQTT
//     13/10/2021  3.1     Edson Midorikawa  ajustado para configuração de credenciais
//     03/10/2022  4.0     Edson Midorikawa  revisado e readaptado para interface serial
//     10/10/2023  4.1     Edson Midorikawa  revisão do código
//     19/09/2024  4.2     Edson Midorikawa  revisão do código
//     15/09/2025  4.3     Edson Midorikawa  revisão do código
//     18/09/2026  4.4     Edson Midorikawa  revisão do código
//--------------------------------------------------------------------------------------
//

// bibliotecas
import processing.serial.*;      // importa biblioteca de comunicacao serial
import java.awt.event.KeyEvent;  // importa biblioteca para leitura de dados da porta serial
import java.io.IOException;

// interface serial
Serial myPort; // definicao do objeto serial

//  ======= CONFIGURACAO SERIAL ==================

    String   porta= "/dev/ttyUSB0";  // CP2102 no Linux (era COM4)
    int   baudrate= 115200;  // 115200 bauds
    char    parity= 'E';     // E=even/par, O=odd/impar
    int   databits= 7;       // 7 bits de dados
    float stopbits= 1.0;     // 1 stop bit

//  ==============================================

// variaveis
String angle="";
String distance="";
String data="";
String noObject;
float  pixsDistance;
int    iAngle, iDistance;
int    index1=0;
int    index2=0;
PFont  orcFont;

// keystroke
int whichKey = -1;  // variavel mantem tecla acionada


// ========================================================================
// funcao setup()
// ========================================================================
void setup() {
    size (960, 600);
    //translate(0,20); 
    smooth();
    
    orcFont = loadFont("OCRAExtended-24.vlw");
    
    // interface serial
    myPort = new Serial(this, porta, baudrate, parity, databits, stopbits);
    // leitura de dados da porta serial até o caractere '#' (para leitura de "angulo,distancia#"
    myPort.bufferUntil('#'); 
    //myPort.bufferUntil('['); 

}

// ========================================================================
// funcao draw
// ========================================================================
void draw() {
    pushMatrix();
    translate(0,40);
    fill(98,245,31);
    textFont(orcFont);
    noStroke();
    fill(0,7);
    rect(0, -40, width, 480+40);
    
    fill(98,245,31); // verde

    // chama funcoes para desenhar o sonar
    drawRadar(); 
    drawLine();
    drawObject();
    drawText();
    popMatrix();
}

// funcao drawRadar()
void drawRadar() {
    pushMatrix();
    //
    fill(255,255,255);
    text("PCS3645 - LabDig II (2026)", 10, 0);
    text("Sistema de Sonar", 10, 30);
    textSize(18);
    text("[Porta serial: "+ porta + " " + databits+parity+int(stopbits)+ " @ " + baudrate + "]", 570, 0);
    //
    translate(480,480);
    noFill();
  
    strokeWeight(1.5);
    stroke(98,245,31);
    // arcos
    arc(0,0,800,800,PI,TWO_PI);
    arc(0,0,600,600,PI,TWO_PI);
    arc(0,0,400,400,PI,TWO_PI);
    arc(0,0,200,200,PI,TWO_PI);

    // desenha segmentos radiais
    line(-480,0,480,0);
    line(0,0,-480*cos(radians(30)),-480*sin(radians(30)));
    line(0,0,-480*cos(radians(60)),-480*sin(radians(60)));
    line(0,0,-480*cos(radians(90)),-480*sin(radians(90)));
    line(0,0,-480*cos(radians(120)),-480*sin(radians(120)));
    line(0,0,-480*cos(radians(150)),-480*sin(radians(150)));
    line(-480*cos(radians(30)),0,480,0);
    popMatrix();
}

// funcao drawObject()
void drawObject() {
    pushMatrix();
    translate(480,480);
    strokeWeight(15); 
    stroke(255,10,10); // vermelho
    // calcula distancia em pixels
    pixsDistance = iDistance*10.0; 
    // limita faixa de apresentacao
    if(iDistance < 50) {
        // desenha objeto        
        point(pixsDistance*cos(radians(iAngle)),-pixsDistance*sin(radians(iAngle)));
    }
    popMatrix();
}   


// funcao drawLine()
void drawLine() {
    pushMatrix();
    strokeWeight(10);
    stroke(30,250,60);
    translate(480,480);
    // desenha linha do sonar
    line(0,0,470*cos(radians(iAngle)),-470*sin(radians(iAngle)));
    popMatrix();
}

// funcao drawText()
void drawText() {
  
    pushMatrix();
    // limita detecao de objetos a 100 cm
    if(iDistance > 100) {
        noObject = "Não Detectado";
    }
    else {
        noObject = "Detectado";
    }
    fill(0,0,0);
    noStroke();
    rect(0, 481, width, 540);
    fill(98,245,31);
    textSize(12);
    text("10cm",590,470);
    text("20cm",690,470);
    text("30cm",790,470);
    text("40cm",890,470);
    textSize(20);
    // imprime dados do sonar
    text("Objeto: " + noObject, 120, 525);
    text("Ângulo: " + iAngle +"°", 500, 525);
    text("Distância: ", 680, 525);
    if(iDistance<50) {
        text("          " + iDistance +" cm", 700, 525);
    }
    else {
        text("          ---", 700, 525);  
    }
    textSize(12);
    fill(98,245,60);
    translate(485+480*cos(radians(30)),468-480*sin(radians(30)));
    rotate(-radians(-60));
    text("30°",0,0);
    resetMatrix();
    translate(482+480*cos(radians(60)),505-480*sin(radians(60)));
    rotate(-radians(-30));
    text("60°",0,0);
    resetMatrix();
    translate(473+480*cos(radians(90)),510-480*sin(radians(90)));
    rotate(radians(0));
    text("90°",0,0);
    resetMatrix();
    translate(462+480*cos(radians(120)),515-480*sin(radians(120)));
    rotate(radians(-30));
    text("120°",0,0);
    resetMatrix();
    translate(467+480*cos(radians(150)),525-480*sin(radians(150)));
    rotate(radians(-60));
    text("150°",0,0);
    popMatrix(); 
}



// ========================================================================
// funcoes para conexao com a porta serial
// ========================================================================

void serialEvent (Serial myPort) { 
    // inicia leitura da porta serial
    try {
        // leitura de dados da porta serial ate o caractere '#' na variavel data
        data = myPort.readStringUntil('#');
        //data = myPort.readStringUntil('[');
        print(data);  // imprime "data" (debug)
        // remove caractere final '#'
        data = data.substring(0,data.length()-1); 
        // encontra indice do caractere ',' e guarda em "index1" 
        index1   = data.indexOf(",");
        // le dados da posicao 0 ate a posicao index1 e guarda em "angle"
        angle    = data.substring(0, index1);
        // le dados da posicao "index+1 ate o final e guarda em "distance"
        distance = data.substring(index1+1, data.length()); 
        println(" -> angle= " + angle + " distance= " + distance);

        // converte variaveis tipo String para tipo inteiro
        iAngle    = int(angle);    // angulo em graus
        iDistance = int(distance); // distancia em cm
        println("angulo= " + iAngle + "° distancia= " + iDistance + "cm");
    }
    catch(RuntimeException e) {
        e.printStackTrace();
    }
}

// funcao keyPressed
// processa tecla acionada (envia para a porta serial)
void keyPressed() {
    whichKey = key;

    myPort.write(key);
    println("");
    println("Enviando tecla '" + key + "' para a porta serial. ");
}
