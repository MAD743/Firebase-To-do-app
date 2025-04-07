import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String filterPriority = 'All';
  bool showCompleted = true;

  Stream<QuerySnapshot> getTasks() {
    final baseQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('tasks');

    Query query = baseQuery.where('parentId', isNull: true);

    if (!showCompleted) {
      query = query.where('completed', isEqualTo: false);
    }

    if (filterPriority != 'All') {
      query = query.where('priority', isEqualTo: filterPriority);
    }

    return query.orderBy('priority').snapshots();
  }

  void toggleComplete(DocumentSnapshot doc) {
    doc.reference.update({'completed': !(doc['completed'] as bool)});
  }

  void deleteTask(DocumentSnapshot doc) {
    doc.reference.delete();
  }

  void addOrEditTask({DocumentSnapshot? doc, String? parentId}) {
    final titleCtrl = TextEditingController(text: doc?['title']);
    String priority = doc?['priority'] ?? 'Medium';

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(doc == null ? 'New Task' : 'Edit Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                DropdownButton<String>(
                  value: priority,
                  items:
                      ['High', 'Medium', 'Low']
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => priority = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final data = {
                    'title': titleCtrl.text,
                    'priority': priority,
                    'completed': false,
                    'parentId': parentId,
                  };
                  if (doc == null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('tasks')
                        .add(data);
                  } else {
                    await doc.reference.update(data);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Widget buildTaskTile(DocumentSnapshot doc) {
    final title = doc['title'];
    final completed = doc['completed'];
    final priority = doc['priority'];
    final id = doc.id;

    Color getColor() {
      switch (priority) {
        case 'High':
          return Colors.red;
        case 'Medium':
          return Colors.orange;
        case 'Low':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ExpansionTile(
        title: Row(
          children: [
            Checkbox(value: completed, onChanged: (_) => toggleComplete(doc)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  decoration:
                      completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: getColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                priority,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        children: [
          SubtaskList(parentId: id),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => addOrEditTask(parentId: id),
                child: const Text("Add Subtask"),
              ),
              TextButton(
                onPressed: () => addOrEditTask(doc: doc),
                child: const Text("Edit"),
              ),
              TextButton(
                onPressed: () => deleteTask(doc),
                child: const Text("Delete"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          DropdownButton<String>(
            value: filterPriority,
            onChanged: (val) => setState(() => filterPriority = val!),
            items:
                ['All', 'High', 'Medium', 'Low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
          ),
          Switch(
            value: showCompleted,
            onChanged: (val) => setState(() => showCompleted = val),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: getTasks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final tasks = snapshot.data!.docs;
          return ListView(
            children: tasks.map((doc) => buildTaskTile(doc)).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => addOrEditTask(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SubtaskList extends StatelessWidget {
  final String parentId;
  const SubtaskList({required this.parentId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('tasks')
              .where('parentId', isEqualTo: parentId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final subtasks = snapshot.data!.docs;

        return Column(
          children:
              subtasks.map((doc) {
                return ListTile(
                  leading: Checkbox(
                    value: doc['completed'],
                    onChanged:
                        (_) => doc.reference.update({
                          'completed': !(doc['completed'] as bool),
                        }),
                  ),
                  title: Text(
                    doc['title'],
                    style: TextStyle(
                      decoration:
                          doc['completed']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => doc.reference.delete(),
                  ),
                );
              }).toList(),
        );
      },
    );
  }
}
