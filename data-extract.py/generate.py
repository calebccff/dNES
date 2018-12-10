import re

def find(s, ch):
    return [i for i, ltr in enumerate(s) if ltr == ch]

instrList = open("table 0.csv").read()
instrList = instrList[instrList.index("\n"):]
instrList = instrList.split("#")

def clean(l):
    for x in find(l, "\n"):
        y = l[x:]
        try:
            l = l[:x]+l[x+y.index(",")]
        except Exception as e:
            pass
    for i in range(len(l)):
        if "\n" in l[i]:
            l[i] = l[i][:l[i].index("\n")]
    return l[1:]

instrList = clean(instrList)

print(instrList)
import os
#os._exit(0)

tables = []
for i in range(2, 113, 2):
    data = open("table "+str(i)+".csv").read()
    data = data[data.index("\n")+1:]
    data = clean(data[data.index("\n")+1:].split("#"))
    for i in range(len(data)):
        data[i] = re.sub("\s\s+", " ", data[i]) #Strip extra spaces
        data[i] = data[i].replace("(", "").replace(")", "")
        data[i] = data[i].replace("Immediate", "imm")

        data[i] = data[i].replace("Zero Page,X", "zex")
        data[i] = data[i].replace("Zero Page,Y", "zey")
        data[i] = data[i].replace("Zero Page", "zer")

        data[i] = data[i].replace("Absolute,X", "abx")
        data[i] = data[i].replace("Absolute,Y", "aby")
        data[i] = data[i].replace("Absolute", "abs")

        data[i] = data[i].replace("Indirect,X", "inx")
        data[i] = data[i].replace("Indirect,Y", "iny")
        data[i] = data[i].replace("Indirect", "abi") #?

        data[i] = data[i].replace("Implied", "imp")
        data[i] = data[i].replace("Accumulator", "acc")
        data[i] = data[i].replace("Relative", "rel")
        #print(data[i])
    data2d = []
    for i in range(int(len(data)/4)):
        data2d.append(data[i*4:(i+1)*4])
    tables.append(data2d)
    print(data2d)
    print("***************************************")

outFile = open("1code.txt", "w")
"""
instrSet[0x65] = instr;
instr = Instr("ADC inx",
&addr_inx,
&op_adc,
2, 6);
"""
template = """
void op_{0}(ushort src){1}"""
# template = """
# instr = Instr("{0} {1}", &addr_{2}, &op_{3}, {4}, {5});
# instrSet[0x{6}] = instr;"""
# toWrite = template.format(
# instrList[i], data[0],
# data[0],
# instrList[i].lower(),
# data[2][0], data[3][0],
# data[1][1:]
# )
for i, table in enumerate(tables):
    toWrite = template.format(instrList[i].lower(),
    "{\n  \n}")
    outFile.write(toWrite)
    print(toWrite)
