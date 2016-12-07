#include <iostream>
#include <sstream>
#include <bitset>

int main() {
    std::string opcode;
    std::bitset<32> instBin;
    while(std::cin >> opcode) {
        //R-type instructions
        if(!opcode.compare("add") || !opcode.compare("sub") || !opcode.compare("mul")) 
        {
            int dst, src1, src2;
            std::cin >> dst >> src1 >> src2;
            if(!opcode.compare("add")) {
                std::bitset<7> opcodeBin(0) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else if(!opcode.compare("sub")) {
                std::bitset<7> opcodeBin(1) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else {
                std::bitset<7> opcodeBin(2) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            std::bitset<5> dstBin(dst), src1Bin(src1), src2Bin(src2);
            std::bitset<10> zero(0);
            for(int i=0; i<5; i++)
                instBin.set(i+20, dstBin[i]);
            for(int i=0; i<5; i++)
                instBin.set(i+15, src1Bin[i]);
            for(int i=0; i<5; i++)
                instBin.set(i+10, src2Bin[i]);
            for(int i=0; i<10; i++)
                instBin.set(i, dstBin[i]);
        }
        //M-type instructions
        else if(!opcode.compare("ldb") || !opcode.compare("ldw") || !opcode.compare("stb") || 
                !opcode.compare("stw") || !opcode.compare("mov") || !opcode.compare("movi"))  
        {
            int dst, src1, offset;
            std::cin >> dst >> src1 >> offset;
            if(!opcode.compare("ldb")) {
                std::bitset<7> opcodeBin(16) ;
                //std::cout << "opcodeBin: " << opcodeBin.to_string() << std::endl;;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
                //std::cout << "instBin: " << instBin.to_string() << std::endl;;
            }
            else if(!opcode.compare("ldw")) {
                std::bitset<7> opcodeBin(17) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else if(!opcode.compare("stb")) {
                std::bitset<7> opcodeBin(18) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else if(!opcode.compare("stw")) {
                std::bitset<7> opcodeBin(19) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else if(!opcode.compare("mov")) {
                std::bitset<7> opcodeBin(20) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else {
                std::bitset<7> opcodeBin(21) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            std::bitset<5> dstBin(dst), src1Bin(src1);
            std::bitset<15> offsetBin(offset);
            for(int i=0; i<5; i++)
                instBin.set(i+20, dstBin[i]);
            for(int i=0; i<5; i++)
                instBin.set(i+15, src1Bin[i]);
            for(int i=0; i<15; i++)
                instBin.set(i, offsetBin[i]);
        }
        //B-type instructions
        else if(!opcode.compare("beq") || !opcode.compare("jump") || !opcode.compare("bz")) {
            int offsetHi, src1, offsetM, offsetLo;
            std::cin >> offsetHi >> src1 >> offsetM >> offsetLo;
            if(!opcode.compare("beq")) {
                std::bitset<7> opcodeBin(48) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else if(!opcode.compare("jump")) {
                std::bitset<7> opcodeBin(49) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            else {
                std::bitset<7> opcodeBin(52) ;
                for(int i=0; i<7; i++)
                    instBin.set(i+25, opcodeBin[i]); 
            }
            std::bitset<5> offsetHiBin(offsetHi), src1Bin(src1), offsetMBin(offsetM);
            std::bitset<10> offsetLoBin(offsetLo);
            for(int i=0; i<5; i++)
                instBin.set(i+20, offsetHiBin[i]);
            for(int i=0; i<5; i++)
                instBin.set(i+15, src1Bin[i]);
            for(int i=0; i<5; i++)
                instBin.set(i+10, offsetMBin[i]);
            for(int i=0; i<10; i++)
                instBin.set(i, offsetLoBin[i]);
        }
        //NOP
        else{
            for(int i=0; i<32; i++)
                instBin.set(i, 1);
        }

        std::stringstream hexInst;
        hexInst.fill('0');
        hexInst.width(8);
        hexInst << std::hex << std::uppercase << instBin.to_ulong();
        std::cout << "Binary: " << instBin.to_string() << std::endl;
        //std::cout << "Hexadecimal: " << hexInst.str() << std::endl;
        std::cout << hexInst.str() << std::endl;
    }
}
