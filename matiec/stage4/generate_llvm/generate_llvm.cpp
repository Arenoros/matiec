#include <llvm/IR/IRBuilder.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/ExecutionEngine/JITSymbol.h>
#include <llvm/ExecutionEngine/SectionMemoryManager.h>
#include <llvm/ExecutionEngine/Orc/CompileUtils.h>
#include <llvm/ExecutionEngine/Orc/IRCompileLayer.h>
#include <llvm/ExecutionEngine/Orc/RTDyldObjectLinkingLayer.h>
#include <llvm/ExecutionEngine/Orc/LLJIT.h>
#include "generate_llvm.h"

void* function_args_parse::visit(input_declaration_list_c* symbol) {
    auto res = new std::vector<llvm::Type*>(symbol->size());
    for (int i = 0; i < symbol->size(); ++i) {
        llvm::Value* val = static_cast<llvm::Value*>(symbol->get_element(i)->accept(*this));
        if (val) {
            input.push_back(val);
        }
    }
    return res;
}

generate_llvm_code::generate_llvm_code() {
    llvm::InitializeNativeTarget();
    llvm::InitializeNativeTargetAsmPrinter();
    llvm::InitializeNativeTargetAsmParser();
    Ctx = llvm::orc::ThreadSafeContext(std::make_unique<llvm::LLVMContext>());
    jit_module = llvm::orc::ThreadSafeModule(std::make_unique<llvm::Module>("Test JIT Compiler", *Ctx.getContext()),
                                             Ctx);
}

void* generate_llvm_code::visit(function_block_declaration_c* symbol) {
    function_args_parse func_args;
    std::vector<llvm::Type*>* param_type = (std::vector<llvm::Type*>*)symbol->var_declarations->accept(func_args);
    //auto struct_type = llvm::StructType::create(*param_type, std::string("test"), false);
    //struct_type.
    llvm::FunctionType* prototype = llvm::FunctionType::get(llvm::Type::getDoubleTy(*Ctx.getContext()),
                                                            *param_type,
                                                            false);
    llvm::Function* func = llvm::Function::Create(prototype,
                                                  llvm::Function::ExternalLinkage,
                                                  "test_func",
                                                  jit_module.getModuleUnlocked());

    printf("FB: %s\n", symbol->fblock_name->token->value);
    symbol->var_declarations->accept(*this);
    symbol->fblock_body->accept(*this);
    return nullptr;
}
