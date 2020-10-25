#!/usr/bin/env python

import sys


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Incorrect number of parameters')
    
    try:
        x = float(sys.argv[1])
        if x <= 1:
            answer = 75 * x ** 2 - 17 * x
        elif x > 20:
            answer = 85 * x / (1 + x)
        else:
            answer = 54 + x**2 / (1 + x)
        
        print(answer)

    except Exception as e:
        sys.exit(f'{e.__class__} occured!')

