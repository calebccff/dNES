
out = open("code.asm", "w")
codes = [[x.split(" 	")[1],x.split(" 	")[0],x.split(" 	")[2].strip()]  for x in open("opcodes.txt").readlines()]
print(codes)
def main():
    while 1:
        try:
            f = open("code.asm")#open(input("Source file name> "), "r")
            break
        except Exception:
            print("Invalid file name")
    lines = f.readlines()
    for line in lines:
        line = line.strip()
        op = findOpcode(line)
        p1 = findParam(1, line)
        p2 = findParam(2, line)

def findOpcode(line):
    global codes
    op = ""
    linecodes = line.split(" ")
    options = [x for x in codes if x[0] == linecodes[0].upper()]
    
    if linecodes[1][0] == "#":
        op = [o[2] for o in options].index("Immediate")
    else if len(linecodes) == 2:
        op = 
    

if __name__ == "__main__":
    main()