import { useLocation } from "wouter";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Receipt, ArrowLeft } from "lucide-react";

export default function InvoiceShare() {
  const [location, navigate] = useLocation();
  const invoiceNumber = decodeURIComponent(location.split("/").pop() ?? "invoice");

  return (
    <div className="min-h-screen bg-[#f7f8f5] px-4 py-10 text-slate-900">
      <Card className="mx-auto max-w-xl rounded-3xl border-slate-200/80 shadow-sm">
        <CardHeader className="text-center">
          <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#173f35] text-white"><Receipt className="h-6 w-6" /></div>
          <CardTitle className="mt-4 font-serif text-3xl">Gajurmukhi Dairy & Store</CardTitle>
          <p className="text-sm text-slate-500">Value for Life · Shared invoice</p>
        </CardHeader>
        <CardContent className="space-y-5 text-center">
          <div className="rounded-2xl bg-slate-50 p-5"><div className="text-xs uppercase tracking-[0.18em] text-slate-400">Invoice reference</div><div className="mt-2 text-2xl font-semibold">{invoiceNumber}</div></div>
          <p className="text-sm leading-6 text-slate-500">This share link identifies the invoice created at the dairy counter. The complete invoice remains stored in the authenticated cloud workspace.</p>
          <Button variant="outline" onClick={() => navigate("/")} className="rounded-xl"><ArrowLeft className="mr-2 h-4 w-4" />Back to Gajurmukhi</Button>
        </CardContent>
      </Card>
    </div>
  );
}
