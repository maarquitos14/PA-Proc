#include<iostream>

int main() {
    int a[16][16], b[16][16], c[16][16];
    for(int i=0;i<16;i++) {
        for(int j=0;j<16;j++) {
            a[i][j] = i*16+j; 
            b[i][j] = 256 + i*16+j; 
        }
    }

    for(int i=0; i<16; i++) {
        for(int j=0; j<16; j++) {
            std::cout << std::hex << a[i][j] << " ";
        }
        std::cout << std::endl;
    }
    for(int i=0; i<16; i++) {
        for(int j=0; j<16; j++) {
            std::cout << std::hex << b[i][j] << " ";
        }
        std::cout << std::endl;
    }

    for(int i=0;i<16;i++) {
        for(int j=0; j<16;j++) {
            c[i][j]=0;
            for(int k=0;k<16;k++) {
                c[i][j]+=a[i][k]*b[k][j];
                std::cout << std::hex << c[i][j] << " "; 
            } 
            std::cout << std::endl;
        }
    }

    for(int i=0; i<16; i++) {
        for(int j=0; j<16; j++) {
            std::cout << std::hex << c[i][j] << " ";
        }
        std::cout << std::endl;
    }
}
