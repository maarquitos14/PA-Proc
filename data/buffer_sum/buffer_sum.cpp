#include<iostream>

int main() {
    int sum=0;
    for(int i=0;i<128;i++) {
        sum += i; 
    }
    std::cout << "sum: " << sum << std::endl;
}
