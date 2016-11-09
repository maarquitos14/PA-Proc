#include <iostream>
#include <bitset>

int main() {
    std::string instruction;
    std::string opcode;
    while(std::cin >> opcode) {
        //R-type instructions
        if(!opcode.compare("add") || !opcode.compare("sub") || !opcode.compare("mul")) 
        {
            int dst, src1, src2;
            std::cin >> dst >> src1 >> src2;
            if(!opcode.compare("add"))
                instruction.append(std::bitset<7>(0).to_string());
            else if(!opcode.compare("sub"))
                instruction.append(std::bitset<7>(1).to_string());
            else
                instruction.append(std::bitset<7>(2).to_string());
            instruction.append(std::bitset<5>(dst).to_string());
            instruction.append(std::bitset<5>(src1).to_string());
            instruction.append(std::bitset<5>(src2).to_string());
            instruction.append(std::bitset<10>(0).to_string());
        }
        //M-type instructions
        else if(!opcode.compare("ldb") || !opcode.compare("ldw") || !opcode.compare("stb") || 
                !opcode.compare("stw") || !opcode.compare("mov") || !opcode.compare("movi"))  
        {
            int dst, src1, offset;
            std::cin >> dst >> src1 >> offset;
            if(!opcode.compare("ldb"))
                instruction.append(std::bitset<7>(16).to_string());
            else if(!opcode.compare("ldw"))
                instruction.append(std::bitset<7>(17).to_string());
            else if(!opcode.compare("stb"))
                instruction.append(std::bitset<7>(18).to_string());
            else if(!opcode.compare("stw"))
                instruction.append(std::bitset<7>(19).to_string());
            else if(!opcode.compare("mov"))
                instruction.append(std::bitset<7>(20).to_string());
            else
                instruction.append(std::bitset<7>(21).to_string());
            instruction.append(std::bitset<5>(dst).to_string());
            instruction.append(std::bitset<5>(src1).to_string());
            instruction.append(std::bitset<15>(offset).to_string());
        }
        //B-type instructions
        else if(!opcode.compare("beq") || !opcode.compare("jump")) {
            int offsetHi, src1, offsetM, offsetLo;
            std::cin >> offsetHi >> src1 >> offsetM >> offsetLo;
            if(!opcode.compare("beq"))
                instruction.append(std::bitset<7>(48).to_string());
            else
                instruction.append(std::bitset<7>(49).to_string());

            instruction.append(std::bitset<5>(offsetHi).to_string());
            instruction.append(std::bitset<5>(src1).to_string());
            instruction.append(std::bitset<5>(offsetM).to_string());
            instruction.append(std::bitset<10>(offsetLo).to_string());
        }
        //NOP
        else{
            instruction.append(std::bitset<32>(1).to_string());
        }

        std::cout << instruction << std::endl;
        instruction.clear();
    }
}
