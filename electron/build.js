const builder = require('electron-builder');

builder.build({
    config: {
        'appId': 'com.wakapippi.vrm2pmx',
        'win': {
            'target': {
                'target': 'zip',
                'arch': [
                    'x64',
                ]
            }
        },
        "extraFiles": [
            "convert.json"
        ],
    }
});