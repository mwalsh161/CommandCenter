import gdspy, numpy, sys

if __name__ == '__main__':
    assert len(sys.argv) == 2, 'Expected filename to read as second argument.'

    lib = gdspy.GdsLibrary()
    lib.read_gds(sys.argv[1])
    topcell = lib.top_level()[0]
    labels = topcell.get_labels()
    
    data = [[label.text, label.position[0], label.position[1], label.layer, label.texttype] for label in labels]
    
    print(data)
    
    # return 0
    
    # print(labels)
