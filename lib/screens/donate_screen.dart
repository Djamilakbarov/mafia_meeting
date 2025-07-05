import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final List<String> _productIds = [
    'donate_1',
    'donate_3',
    'donate_5',
    'donate_10',
    'donate_50',
    'donate_99',
    'donate_499',
  ];

  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      print('Store not available');
      return;
    }

    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails(_productIds.toSet());
    if (response.error != null) {
      print('Error: \${response.error}');
      return;
    }

    setState(() {
      _products = response.productDetails;
    });
  }

  Future<void> _buy(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isVip': true,
        'lastDonation': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Спасибо за поддержку! Вы стали VIP 😊')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поддержать проект 💖')),
      body: _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(product.title),
                    subtitle: Text(product.description),
                    trailing: Text(product.price),
                    onTap: () => _buy(product),
                  ),
                );
              },
            ),
    );
  }
}
