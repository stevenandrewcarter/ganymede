"""
Ganymede is a tool that will convert existing Jupyter notebooks into a productionable API so that 
the models defined can be used as part of an API call stack instead of being a workbook. The tool 
provides a few options on how to convert the workbook, either making the entire solution API driven
or just extracting code blocks from a workbook and allowing authors to import the source instead.
"""
import os
import json
import click

if __name__ == "__main__":
    print(os.getcwd())
    with open("./samples/test.ipynb", encoding='utf8') as f:
        data = json.load(f)

        print("Type:", type(data))
        print("Contents", data["cells"])
        for cell in data["cells"]:
            print(cell["source"])
