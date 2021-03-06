/*
 * Copyright 2020 Stephen Tetley
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

namespace SheetIO/Internal/Cell {


    pub def getCellType(cell: ##org.apache.poi.ss.usermodel.Cell): Result[##org.apache.poi.ss.usermodel.CellType, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.getCellType(); 
        try {
            let ans = getCellType(cell);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("getCellType")
        }

    pub def setCellType(cell: ##org.apache.poi.ss.usermodel.Cell, 
                        typ: ##org.apache.poi.ss.usermodel.CellType): Result[Unit, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.setCellType(##org.apache.poi.ss.usermodel.CellType); 
        try {
            let ans = setCellType(cell, typ);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("setCellType")
        }

     
    pub def getBooleanCellValue(cell: ##org.apache.poi.ss.usermodel.Cell): Result[Bool, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.getBooleanCellValue(); 
        try {
            let ans = getBooleanCellValue(cell);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("getBooleanCellValue")
        }


    pub def getStringCellValue(cell: ##org.apache.poi.ss.usermodel.Cell): Result[String, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.getStringCellValue(); 
        try {
            let ans = getStringCellValue(cell);
            if (not Object.isNull(ans)) Ok(ans) else Ok("")
        } catch {
            case _: ##java.lang.Exception => Err("getStringCellValue")
        }

    pub def getNumericCellValue(cell: ##org.apache.poi.ss.usermodel.Cell): Result[Float64, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.getNumericCellValue(); 
        try {
            let ans = getNumericCellValue(cell);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("getNumericCellValue")
        }


    pub def getLocalDateTimeCellValue(cell: ##org.apache.poi.ss.usermodel.Cell): Result[##java.time.LocalDateTime, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.getLocalDateTimeCellValue(); 
        try {
            let ans = getLocalDateTimeCellValue(cell);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("getLocalDateTimeCellValue")
        }


    pub def setBooleanCellValue(cell: ##org.apache.poi.ss.usermodel.Cell, value: Bool): Result[Unit, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.setCellValue(Bool); 
        try {
            let ans = setCellValue(cell, value);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("setBooleanCellValue")
        }

    pub def setNumericCellValue(cell: ##org.apache.poi.ss.usermodel.Cell, value: Float64): Result[Unit, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.setCellValue(Float64); 
        try {
            let ans = setCellValue(cell, value);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("setNumericCellValue")
        }

    pub def setStringCellValue(cell: ##org.apache.poi.ss.usermodel.Cell, 
                               value: String): Result[Unit, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.setCellValue(String); 
        try {
            let ans = setCellValue(cell, value);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("setStringCellValue")
        }


    pub def setLocalDateTimeCellValue(cell: ##org.apache.poi.ss.usermodel.Cell, 
                                      value: ##java.time.LocalDateTime): Result[Unit, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.setCellValue(##java.time.LocalDateTime); 
        try {
            let ans = setCellValue(cell, value);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("setLocalDateTimeCellValue")
        }

    pub def setLocalDateCellValue(cell: ##org.apache.poi.ss.usermodel.Cell, 
                                  value: ##java.time.LocalDate): Result[Unit, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.setCellValue(##java.time.LocalDate); 
        try {
            let ans = setCellValue(cell, value);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("setLocalDateCellValue") 
        }


    pub def setCellStyle(cell: ##org.apache.poi.ss.usermodel.Cell, 
                         style: ##org.apache.poi.ss.usermodel.CellStyle): Result[Unit, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.setCellStyle(##org.apache.poi.ss.usermodel.CellStyle); 
        try {
            let ans = setCellStyle(cell, style);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("setCellStyle")
        }

   pub def getCellStyle(cell: ##org.apache.poi.ss.usermodel.Cell): Result[##org.apache.poi.ss.usermodel.CellStyle, String] & Impure = 
        import org.apache.poi.ss.usermodel.Cell.getCellStyle(); 
        try {
            let ans = getCellStyle(cell);
            Ok(ans)
        } catch {
            case _: ##java.lang.Exception => Err("getCellStyle")
        }

}

