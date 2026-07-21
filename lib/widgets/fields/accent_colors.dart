import 'package:flutter/material.dart';

import '../../app/theme.dart';

class WidgetsFieldsAccentColors extends FormField<Color> {
  WidgetsFieldsAccentColors({
    super.key,
    super.onSaved,
    super.validator,
    super.autovalidateMode,
    Color initialValue = Colors.transparent,
    ValueChanged<Color>? onChange,
  }) : super(
         initialValue: initialValue,
         builder: (FormFieldState<Color> state) {
           final availableColors = [
             Colors.transparent,

             AppTheme.darkGreen,
             AppTheme.green,
             AppTheme.lightGreen,

             AppTheme.darkBlue,
             AppTheme.blue,
             AppTheme.lightBlue,

             AppTheme.darkPurple,
             AppTheme.purple,
             AppTheme.lightPurple,

             AppTheme.darkYellow,
             AppTheme.yellow,
             AppTheme.lightYellow,

             AppTheme.darkOrange,
             AppTheme.orange,
             AppTheme.lightOrange,

             AppTheme.darkRed,
             AppTheme.red,
             AppTheme.lightRed,
           ];

           return Wrap(
             children: availableColors.map((color) {
               final isSelected = state.value == color;
               return MouseRegion(
                 cursor: SystemMouseCursors.click,
                 child: GestureDetector(
                   onTap: () {
                     state.didChange(color);
                     onChange?.call(color);
                   },
                   child: Stack(
                     children: [
                       Container(
                         margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                         width: 30,
                         height: 30,
                         decoration: BoxDecoration(
                           color: color,
                           borderRadius: BorderRadius.circular(3),
                           border: Border.all(color: color == Colors.transparent ? AppTheme.inputBorder : Colors.transparent, width: 1),
                         ),
                       ),
                       if (color == Colors.transparent)
                         const Positioned.fill(child: Icon(Icons.close, color: AppTheme.inputBorder, size: 18)),
                       if (isSelected) const Positioned.fill(child: Icon(Icons.check, color: Colors.white, size: 18)),
                     ],
                   ),
                 ),
               );
             }).toList(),
           );
         },
       );
}
