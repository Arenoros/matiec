#pragma once

#include <llvm/ExecutionEngine/Orc/ThreadSafeModule.h>

#include "absyntax/visitor.h"

class function_args_parse : public iterator_visitor_c {
    std::vector<llvm::Value*> input;
    std::vector<llvm::Value*> output;

public:
    function_args_parse() {}
    void* visit(input_declaration_list_c* symbol) override;
    void* visit(output_declarations_c* symbol) override;
    void* visit(lreal_type_name_c* symbol) {
        return NULL;
    }
    void* visit(en_param_declaration_c* symbol) {
        return NULL;
    }
    
};

class generate_llvm_code : public iterator_visitor_c {
    llvm::orc::ThreadSafeContext Ctx;
    llvm::orc::ThreadSafeModule jit_module;

public:
    generate_llvm_code();

    void* visit(function_block_declaration_c* symbol) override;

    void* visit(function_invocation_c* symbol) {
        printf("Function %s(", symbol->function_name->token->value);
        return nullptr;
    }
    void* visit(structure_type_declaration_c* symbol) override {
        printf("Struct: %s\n", symbol->structure_type_name->token->value);
        symbol->structure_specification->accept(*this);
        return nullptr;
    }
    ~generate_llvm_code() override {}

private:
};