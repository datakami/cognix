import sys
import json

def main():
    nix_attrs_json = sys.argv[1]
    max_layers = int(sys.argv[2])
    file_to_rewrite = sys.argv[3]
    with open(nix_attrs_json) as f:
        nix_data = json.load(f)
    with open(file_to_rewrite) as f:
        data = json.load(f)
    paths = {g['path']: g['narSize'] for g in nix_data['graph']}
    layers = []
    for layer in data['store_layers']:
        for l in layer:
            # ([paths], size)
            layers.append(([l], paths[l]))
    while len(layers) > max_layers:
        # find the adjacent layers with the smallest size
        min_size = 1e100
        min_idx = -1
        for i in range(len(layers) - 1):
            size = layers[i][1] + layers[i + 1][1]
            if size < min_size:
                min_size = size
                min_idx = i
        # merge the layers
        layers[min_idx] = (layers[min_idx][0] + layers[min_idx + 1][0], min_size)
        layers.pop(min_idx + 1)
    data['store_layers'] = [l[0] for l in layers]
    with open(file_to_rewrite, 'w') as f:
        json.dump(data, f)

main()
