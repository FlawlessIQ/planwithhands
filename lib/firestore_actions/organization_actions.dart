import 'dart:developer'; // Added for log
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/constants/firestore_names.dart';
import 'package:hands_app/data/models/location_data.dart';
import 'package:hands_app/data/models/organization_data.dart';

Future<int?> getIncrementedOrganizationId() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    final CollectionReference collection = firestore.collection(
      FirestoreCollectionNames.organizationTable,
    );

    QuerySnapshot snapshot = await collection.get();

    List<int> documentIds =
        snapshot.docs
            .map(
              (doc) => int.tryParse(doc.id) ?? 0,
            ) // Convert to int, default to 0 if invalid
            .toList();

    // find the highest id, increment it
    // if the docs are empty (shouldn't happen), use 1000
    if (documentIds.isEmpty) {
      log( // Replaced print with log
        'Theres no org ids.  This is a problem, possibly a permissions issue',
      );
      return 1000;
    } else {
      documentIds.sort();
      return documentIds.last + 1;
    }
  } catch (e) {
    log( // Replaced print with log
      'Error inserting new organization data: $e.  Its likely because of doc id insert',
    );
    return null;
  }
}

Future<OrganizationData?> insertNewOrganization({
  required OrganizationData organizationData,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    // Insert the new organization data into Firestore
    await firestore
        .collection(FirestoreCollectionNames.organizationTable)
        .doc(organizationData.id.toString())
        .set(organizationData.toJson());

    // Fetch the document back to confirm the data was inserted
    DocumentSnapshot snapshot =
        await firestore
            .collection(FirestoreCollectionNames.organizationTable)
            .doc(organizationData.id.toString())
            .get();

    if (snapshot.exists) {
      // If document exists, return the data (converted to OrganizationData)
      return OrganizationData.fromJson(snapshot.data() as Map<String, dynamic>);
    } else {
      log('Document not found after insertion'); // Replaced print with log
      return null;
    }
  } catch (e) {
    log('Error inserting new organization data: $e'); // Replaced print with log
    return null;
  }
}

Future<OrganizationData?> getOrganizationById(String organizationId) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    // Fetch the document from Firestore
    DocumentSnapshot snapshot =
        await firestore
            .collection(FirestoreCollectionNames.organizationTable)
            .doc(organizationId)
            .get();

    if (snapshot.exists && snapshot.data() != null) {
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      data['organizationId'] = snapshot.id;
      log('Raw organization data: $data'); // Debug log
      try {
        return OrganizationData.fromJson(data);
      } catch (e, st) {
        log('Error parsing organization data: $e\nData: $data\nStack: $st');
        return null;
      }
    } else {
      log('Organization not found for ID: $organizationId'); // Replaced print with log
      return null;
    }
  } catch (e) {
    log('Error fetching organization data: $e'); // Replaced print with log
    return null;
  }
}

Future<OrganizationData?> updateOrganization({
  required OrganizationData organizationData,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    // Update the existing organization data in Firestore
    await firestore
        .collection(FirestoreCollectionNames.organizationTable)
        .doc(organizationData.id.toString())
        .update(organizationData.toJson()); // Update the fields with new data

    // Fetch the document back to confirm the update was successful
    DocumentSnapshot snapshot =
        await firestore
            .collection(FirestoreCollectionNames.organizationTable)
            .doc(organizationData.id.toString())
            .get();

    if (snapshot.exists) {
      // If the document exists, return the updated data (converted to OrganizationData)
      return OrganizationData.fromJson(snapshot.data() as Map<String, dynamic>);
    } else {
      log('Document not found after update'); // Replaced print with log
      return null;
    }
  } catch (e) {
    log('Error updating organization data: $e'); // Replaced print with log
    return null;
  }
}

Future<List<LocationData>> getLocationsForOrganization(
  String organizationId,
) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    log('Fetching locations for organization: $organizationId'); // Debug log
    
    // Query the top-level locations collection filtered by organizationId
    final QuerySnapshot snapshot = await firestore
        .collection('locations') // Top-level locations collection
        .where('organizationId', isEqualTo: organizationId) // Filter by organizationId
        .get();

    log('Found ${snapshot.docs.length} locations'); // Debug log

    // Convert each document into a LocationData object
    List<LocationData> locations = snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['locationId'] = doc.id; // Add the document ID as locationId
      log('Location data: $data'); // Debug log
      return LocationData.fromJson(data);
    }).toList();

    return locations;
  } catch (e) {
    log('Error fetching locations: $e'); // Replaced print with log
    return [];
  }
}
