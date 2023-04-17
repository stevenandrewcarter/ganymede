import click
import os
import json

if __name__ == "__main__":
    print(os.getcwd())
    with open("./samples/test.ipynb") as f:
        data = json.load(f)

        print("Type:", type(data))
        print("Contents", data["cells"])
        for cell in data["cells"]:
            print(cell["source"])
