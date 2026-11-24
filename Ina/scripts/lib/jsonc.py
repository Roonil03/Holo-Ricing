"""Original MIT JSON-with-comments editor. Preserve untouched source spans."""
import json
import re
from engine import Error

TOKEN = re.compile(r'\s+|//[^\n]*(?:\n|$)|/\*.*?\*/|"(?:\\.|[^"\\])*"|[{}\[\]:,]|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null', re.DOTALL)


def merge(text, wanted):
    tokens = []
    offset = 0
    while offset < len(text):
        match = TOKEN.match(text, offset)
        if not match:
            raise Error(f'Invalid settings JSONC at character {offset}.')
        token = match.group()
        if not token.isspace() and not token.startswith(('//', '/*')):
            tokens.append((token, match.start(), match.end()))
        offset = match.end()
    index = 0

    def parse():
        nonlocal index
        if index == len(tokens):
            raise Error('Incomplete settings JSONC.')
        token, start, end = tokens[index]
        index += 1
        props = None
        if token in ('{', '['):
            closing = '}' if token == '{' else ']'
            props = {} if token == '{' else None
            while index < len(tokens) and tokens[index][0] != closing:
                if props is not None:
                    key = tokens[index][0]
                    if not key.startswith('"'):
                        raise Error('Settings object keys must be quoted.')
                    key = json.loads(key)
                    if key in props:
                        raise Error(f'Duplicate settings key: {key}')
                    index += 1
                    if index >= len(tokens) or tokens[index][0] != ':':
                        raise Error('Expected a colon after a settings key.')
                    index += 1
                    props[key] = parse()
                else:
                    parse()
                if index < len(tokens) and tokens[index][0] == ',':
                    index += 1
                elif index < len(tokens) and tokens[index][0] != closing:
                    raise Error('Expected comma in settings JSONC.')
            if index >= len(tokens):
                raise Error('Unclosed settings JSONC container.')
            end = tokens[index][2]
            index += 1
        else:
            try:
                json.loads(token)
            except ValueError as error:
                raise Error('Invalid settings JSONC value.') from error
        return (start, end, props)

    root = parse()
    if index != len(tokens) or root[2] is None:
        raise Error('Settings must contain one JSON object.')

    def update(node, values):
        start, end, props = node
        edits = []
        missing = {}
        for key, value in values.items():
            if key not in props:
                missing[key] = value
            else:
                child = props[key]
                replacement = update(child, value) if isinstance(value, dict) and child[2] is not None else json.dumps(value, ensure_ascii=False)
                edits.append((child[0], child[1], replacement))
        if missing:
            before_close = [t[0] for t in tokens if start < t[1] < end - 1]
            comma = ',' if props and before_close[-1] != ',' else ''
            fragment = ',\n'.join('  ' + json.dumps(k) + ': ' + json.dumps(v, ensure_ascii=False) for k, v in missing.items())
            edits.append((end - 1, end - 1, comma + '\n' + fragment + '\n'))
        result = text[start:end]
        for a, b, replacement in sorted(edits, reverse=True):
            result = result[:a-start] + replacement + result[b-start:]
        return result

    return text[:root[0]] + update(root, wanted) + text[root[1]:]
