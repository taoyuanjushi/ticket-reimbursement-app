import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TicketImportedFile {
  const TicketImportedFile({
    required this.sourcePath,
    required this.fileName,
    required this.fileType,
  });

  final String sourcePath;
  final String fileName;
  final String fileType;
}

class TicketStoredFile {
  const TicketStoredFile({
    required this.filePath,
    required this.fileName,
    required this.fileType,
  });

  final String filePath;
  final String fileName;
  final String fileType;
}

class TicketFileService {
  TicketFileService();

  final ImagePicker _imagePicker = ImagePicker();

  Future<TicketImportedFile?> pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      return null;
    }

    return TicketImportedFile(
      sourcePath: image.path,
      fileName: path.basename(image.path),
      fileType: 'image',
    );
  }

  Future<TicketImportedFile?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final pickedFile = result.files.single;
    if (pickedFile.path == null) {
      return null;
    }

    return TicketImportedFile(
      sourcePath: pickedFile.path!,
      fileName: pickedFile.name,
      fileType: 'pdf',
    );
  }

  Future<TicketStoredFile> importFile(TicketImportedFile file) async {
    final sourceFile = File(file.sourcePath);
    final storageDirectory = await _attachmentsDirectory();
    final originalExtension = path.extension(file.fileName);
    final extension = originalExtension.isEmpty
        ? _fallbackExtension(file.fileType)
        : originalExtension.toLowerCase();
    final storedPath = path.join(
      storageDirectory.path,
      'ticket_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    await sourceFile.copy(storedPath);

    return TicketStoredFile(
      filePath: storedPath,
      fileName: file.fileName,
      fileType: file.fileType,
    );
  }

  Future<void> deleteStoredFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return;
    }

    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> attachmentsDirectory() {
    return _attachmentsDirectory();
  }

  Future<Directory> _attachmentsDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      path.join(documentsDirectory.path, 'ticket_attachments'),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  String _fallbackExtension(String fileType) {
    switch (fileType) {
      case 'pdf':
        return '.pdf';
      case 'image':
        return '.jpg';
      default:
        return '';
    }
  }
}
