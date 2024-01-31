import 'package:app/src/features/cardapio/interactor/cubit/produtos_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class BuscaMesas extends StatefulWidget {
  final String category;
  const BuscaMesas({super.key, required this.category});

  @override
  State<BuscaMesas> createState() => _BuscaMesasState();
}

class _BuscaMesasState extends State<BuscaMesas> {
  final _searchController = SearchController();

  final ProdutosCubit _produtosCubit = Modular.get<ProdutosCubit>();

  @override
  void initState() {
    super.initState();
    _searchController.text = "Mesa 1";

    print(widget.category);
    // _produtosCubit.getProdutos(widget.category);
  }

  final leading = InkWell(
    onTap: () {
      Modular.to.pop();
    },
    borderRadius: BorderRadius.circular(50),
    child: const Padding(
      padding: EdgeInsets.all(8.0),
      child: Icon(Icons.arrow_back_outlined),
    ),
  );

  final trailing = [
    IconButton(
      icon: const Icon(Icons.keyboard_voice),
      onPressed: () {},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // return SearchBar(
    //   leading: leading,
    //   trailing: trailing,
    //   elevation: const MaterialStatePropertyAll(0),
    //   padding: const MaterialStatePropertyAll(
    //     EdgeInsets.symmetric(
    //       horizontal: 15,
    //       // vertical: 4,
    //     ),
    //   ),
    //   constraints: BoxConstraints(
    //     maxWidth: MediaQuery.of(context).size.width - 20,
    //   ),
    //   shape: const MaterialStatePropertyAll(
    //     RoundedRectangleBorder(
    //       borderRadius: BorderRadius.all(
    //         Radius.circular(5),
    //       ),
    //     ),
    //   ),
    //   onTap: () {
    //     // _searchController.openView();
    //   },
    // );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        decoration: InputDecoration(
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.white,
          hintText: 'Pesquisar...',
          prefixIcon: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_outlined),
          ),
        ),
        onChanged: (value) => print(value),
      ),
    );
    // return SearchAnchor(
    //   searchController: _searchController,
    //   builder: (BuildContext context, SearchController controller) {
    // return SearchBar(
    //   leading: leading,
    //   trailing: trailing,
    //   elevation: const MaterialStatePropertyAll(0),
    //   padding: const MaterialStatePropertyAll(
    //     EdgeInsets.symmetric(horizontal: 15),
    //   ),
    //   constraints: BoxConstraints(
    //     maxWidth: MediaQuery.of(context).size.width - 20,
    //   ),
    //   shape: const MaterialStatePropertyAll(
    //     RoundedRectangleBorder(
    //       borderRadius: BorderRadius.all(
    //         Radius.circular(5),
    //       ),
    //     ),
    //   ),
    //   onTap: () {
    //     _searchController.openView();
    //   },
    // );
    //   },
    //   suggestionsBuilder: (BuildContext context, SearchController controller) {
    //     final keyword = controller.value.text;
    //     return List.generate(5, (index) => 'Item $index').where((element) => element.toLowerCase().startsWith(keyword.toLowerCase())).map(
    //           (item) => GestureDetector(
    //             onTap: () {
    //               setState(() {
    //                 controller.closeView(item);
    //               });
    //             },
    //             child: Card(
    //               color: Colors.amber,
    //               child: Center(child: Text(item)),
    //             ),
    //           ),
    //         );
    //   },
    //   viewBuilder: (Iterable<Widget> suggestions) {
    //     return GridView.builder(
    //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    //         crossAxisCount: 3,
    //       ),
    //       itemCount: suggestions.length,
    //       itemBuilder: (BuildContext context, int index) {
    //         return suggestions.elementAt(index);
    //       },
    //     );
    //   },
    // );
  }
}
