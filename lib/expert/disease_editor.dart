import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Map disease names to asset image paths (same as farmer side)
const Map<String, String> diseaseImages = {
  'Anthracnose': 'assets/diseases/anthracnose.jpg',
  'Bacterial black spot': 'assets/diseases/backterial_blackspot1.jpg',
  'Dieback': 'assets/diseases/dieback.jpg',
  'Powdery mildew': 'assets/diseases/powdery_mildew3.jpg',
};

const List<String> mainDiseases = [
  'Anthracnose',
  'Bacterial black spot',
  'Dieback',
  'Powdery mildew',
];

class DiseaseEditor extends StatefulWidget {
  const DiseaseEditor({Key? key}) : super(key: key);

  @override
  State<DiseaseEditor> createState() => _DiseaseEditorState();
}

class _DiseaseEditorState extends State<DiseaseEditor> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Diseases'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('diseases').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No diseases found.'));
          }
          // Filter only the main diseases
          final docs =
              snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return mainDiseases.contains(data['name']);
              }).toList();
          // Sort by mainDiseases order
          docs.sort(
            (a, b) => mainDiseases
                .indexOf((a.data() as Map<String, dynamic>)['name'])
                .compareTo(
                  mainDiseases.indexOf(
                    (b.data() as Map<String, dynamic>)['name'],
                  ),
                ),
          );
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown';
              final imagePath =
                  diseaseImages[name] ?? 'assets/diseases/healthy.jpg';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      imagePath,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(data['scientificName'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed:
                        () => _showEditDiseaseDialog(
                          context,
                          doc.id,
                          data,
                          imagePath,
                        ),
                  ),
                  onTap:
                      () => _showEditDiseaseDialog(
                        context,
                        doc.id,
                        data,
                        imagePath,
                      ),
                ),
              );
            },
          );
        },
      ),
      // No floatingActionButton
    );
  }

  void _showEditDiseaseDialog(
    BuildContext context,
    String? docId,
    Map<String, dynamic> data,
    String imagePath,
  ) {
    // Use lists of controllers for dynamic fields
    List<TextEditingController> symptomControllers =
        List<TextEditingController>.from(
          (data['symptoms'] ?? ['']).map<TextEditingController>(
            (s) => TextEditingController(text: s),
          ),
        );
    List<TextEditingController> treatmentControllers =
        List<TextEditingController>.from(
          (data['treatments'] ?? ['']).map<TextEditingController>(
            (t) => TextEditingController(text: t),
          ),
        );

    void addSymptomField() {
      symptomControllers.add(TextEditingController());
    }

    void removeSymptomField(int idx) {
      if (symptomControllers.length > 1) {
        symptomControllers.removeAt(idx);
      }
    }

    void addTreatmentField() {
      treatmentControllers.add(TextEditingController());
    }

    void removeTreatmentField(int idx) {
      if (treatmentControllers.length > 1) {
        treatmentControllers.removeAt(idx);
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Edit  ${data['name']}'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Disease image (now tappable to expand)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Image.asset(
                                              imagePath,
                                              width:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.8,
                                              height:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.height *
                                                  0.4,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              imagePath,
                              width: 100,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['scientificName'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Symptoms',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(
                          symptomControllers.length,
                          (i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: symptomControllers[i],
                                    decoration: InputDecoration(
                                      labelText: 'Symptom  ${i + 1}',
                                      border: OutlineInputBorder(),
                                    ),
                                    minLines: 2,
                                    maxLines: null, // auto-expand
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      symptomControllers.length > 1
                                          ? () => setState(
                                            () => removeSymptomField(i),
                                          )
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add, color: Colors.green),
                            label: const Text('Add Symptom'),
                            onPressed: () => setState(addSymptomField),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Treatments',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(
                          treatmentControllers.length,
                          (i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: treatmentControllers[i],
                                    decoration: InputDecoration(
                                      labelText: 'Treatment  ${i + 1}',
                                      border: OutlineInputBorder(),
                                    ),
                                    minLines: 2,
                                    maxLines: null, // auto-expand
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      treatmentControllers.length > 1
                                          ? () => setState(
                                            () => removeTreatmentField(i),
                                          )
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add, color: Colors.green),
                            label: const Text('Add Treatment'),
                            onPressed: () => setState(addTreatmentField),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final symptoms =
                            symptomControllers
                                .map((c) => c.text.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                        final treatments =
                            treatmentControllers
                                .map((c) => c.text.trim())
                                .where((t) => t.isNotEmpty)
                                .toList();
                        final docData = {
                          'name': data['name'],
                          'scientificName': data['scientificName'],
                          'symptoms': symptoms,
                          'treatments': treatments,
                        };
                        if (docId != null) {
                          await FirebaseFirestore.instance
                              .collection('diseases')
                              .doc(docId)
                              .set(docData);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
          ),
    );
  }
}
