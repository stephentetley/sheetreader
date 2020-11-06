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


package flix.runtime.spt.sheetio;


import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;

import java.util.Iterator;

public class RowIterator {

    private Iterator<Row> iter;

    public RowIterator(Sheet sheet) throws Exception {
        this.iter = sheet.rowIterator();
    }

    public boolean hasNext() {
        return this.iter.hasNext();
    }

    public Row next() throws Exception { return this.iter.next(); }

    public void close() throws Exception { return; }

}