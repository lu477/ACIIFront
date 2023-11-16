import 'package:http/http.dart';

Future getData(url) async {
  Response response = await get(url);
  if(response.body.isNotEmpty){
  return response.body.toString();
  }
}