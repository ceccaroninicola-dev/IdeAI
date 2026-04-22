// Helper per il download di file — usa l'implementazione web o stub
// in base alla piattaforma, tramite conditional import.
export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';
