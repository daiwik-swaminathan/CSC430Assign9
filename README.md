# Abstract Syntax 
Each AST is a Brat object. Every AST object has a type field that defines exactly what it is.
ex. an AppC object would have type field = "AppC"

Object attributes are "defined as you need them". Seems flexible but this, combined with a lack of types, makes a PAIG interpreter written in Brat prone to bad arguments and missing expression attributes.

1) NumC:
    - type
    - value
2) StrC:
    - type  
    - value
3) IdC:
    - type    
    - value
4) IfC:
    - type
    - expr1 
    - expr2
    - expr3 
5) BlamC:
    - type
    - clo-args
    - clo-body
6) AppC:
    - type
    - fun
    - fun-args